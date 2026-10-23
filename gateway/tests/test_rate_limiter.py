"""Tests for gateway/rate_limiter.py — per-user admission limit, per-case
admission limit, and global capacity cap using Firestore-backed atomic
transactions."""

from __future__ import annotations

import hashlib
from datetime import datetime, timedelta, timezone

import pytest

from gateway.admission import AdmissionStatus
from gateway.rate_limiter import (
    admit_case_request,
    admit_global_request,
    admit_user_request,
    compute_global_capacity,
)

UID_OWNER = "uid-owner"
UID_OTHER = "uid-other"
UID_HASH_OWNER = hashlib.sha256(UID_OWNER.encode("utf-8")).hexdigest()


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _future_iso(seconds_ahead):
    return (datetime.now(timezone.utc) + timedelta(seconds=seconds_ahead)).isoformat()


def _past_iso(seconds_ago):
    return (datetime.now(timezone.utc) - timedelta(seconds=seconds_ago)).isoformat()


def _break_shared_state(db):
    """Make the shared transaction store unavailable."""

    def failing_run_transaction(work):
        raise Exception("Firestore unavailable")

    db.run_transaction = failing_run_transaction


class TestPerUserRateLimiter:
    def test_first_five_requests_admitted(self, make_db):
        db = make_db({})
        for i in range(5):
            result = admit_user_request(
                db, UID_OWNER, max_requests=5, window_seconds=600
            )
            assert result.admitted is True, f"Request {i+1} should be admitted"
            assert result.retry_after is None
            assert result.status is AdmissionStatus.ADMITTED

    def test_sixth_request_rejected_with_429(self, make_db):
        db = make_db({})
        for _ in range(5):
            admit_user_request(db, UID_OWNER, max_requests=5, window_seconds=600)

        result = admit_user_request(
            db, UID_OWNER, max_requests=5, window_seconds=600
        )
        assert result.admitted is False
        assert result.rejected is True
        assert result.status is AdmissionStatus.REJECTED
        assert result.retry_after is not None
        assert result.retry_after > 0
        assert result.retry_after <= 600

    def test_rejected_request_not_counted(self, make_db):
        db = make_db({})
        for _ in range(5):
            admit_user_request(db, UID_OWNER, max_requests=5, window_seconds=600)

        result = admit_user_request(db, UID_OWNER, max_requests=5, window_seconds=600)
        assert result.rejected is True

        result = admit_user_request(db, UID_OWNER, max_requests=5, window_seconds=600)
        assert result.rejected is True

    def test_different_uids_independent_counters(self, make_db):
        db = make_db({})
        for _ in range(5):
            admit_user_request(db, UID_OWNER, max_requests=5, window_seconds=600)

        result = admit_user_request(db, UID_OTHER, max_requests=5, window_seconds=600)
        assert result.admitted is True

    def test_window_expiry_allows_new_requests(self, make_db):
        old_store = {
            ("rate_limits", f"user:{UID_HASH_OWNER}"): {
                "timestamps": [_past_iso(700)] * 5,
                "updated_at": _past_iso(700),
            }
        }
        db = make_db(old_store)

        result = admit_user_request(db, UID_OWNER, max_requests=5, window_seconds=600)
        assert result.admitted is True

    def test_rolling_window_filters_old_timestamps(self, make_db):
        old_store = {
            ("rate_limits", f"user:{UID_HASH_OWNER}"): {
                "timestamps": [
                    _past_iso(700),
                    _past_iso(700),
                    _now_iso(),
                    _now_iso(),
                ],
                "updated_at": _now_iso(),
            }
        }
        db = make_db(old_store)

        for _ in range(3):
            result = admit_user_request(
                db, UID_OWNER, max_requests=5, window_seconds=600
            )
            assert result.admitted is True

        result = admit_user_request(db, UID_OWNER, max_requests=5, window_seconds=600)
        assert result.rejected is True

    def test_shared_state_failure_is_unavailable_not_rejected(self, make_db):
        db = make_db({})
        _break_shared_state(db)

        result = admit_user_request(
            db, UID_OWNER, max_requests=5, window_seconds=600, fail_closed=True
        )
        assert result.status is AdmissionStatus.UNAVAILABLE
        assert result.unavailable is True
        assert result.rejected is False
        assert result.admitted is False
        assert result.retry_after is None

    def test_fail_open_option(self, make_db):
        db = make_db({})
        _break_shared_state(db)

        result = admit_user_request(
            db, UID_OWNER, max_requests=5, window_seconds=600, fail_closed=False
        )
        assert result.admitted is True
        assert result.status is AdmissionStatus.ADMITTED


class TestGlobalCapacityCap:
    def test_global_capacity_admits_under_limit(self, make_db):
        db = make_db({})
        result = admit_global_request(db, capacity=10, window_seconds=3600)
        assert result.admitted is True
        assert result.status is AdmissionStatus.ADMITTED

    def test_global_capacity_rejects_at_limit(self, make_db):
        db = make_db({})
        for _ in range(10):
            admit_global_request(db, capacity=10, window_seconds=3600)

        result = admit_global_request(db, capacity=10, window_seconds=3600)
        assert result.admitted is False
        assert result.rejected is True
        assert result.status is AdmissionStatus.REJECTED
        assert result.retry_after is not None
        assert result.retry_after > 0

    def test_global_capacity_window_reset(self, make_db):
        old_store = {
            ("rate_limits", "global:capacity"): {
                "window_start": _past_iso(4000),
                "used": 10,
                "capacity": 10,
            }
        }
        db = make_db(old_store)

        result = admit_global_request(db, capacity=10, window_seconds=3600)
        assert result.admitted is True

    def test_compute_global_capacity(self):
        assert compute_global_capacity(0, 5) == 0
        assert compute_global_capacity(10, 5) == 50
        assert compute_global_capacity(1, 5) == 5
        assert compute_global_capacity(100, 5) == 500
        assert compute_global_capacity(-1, 5) == 0
        assert compute_global_capacity(10, 0) == 10

    def test_concurrent_admissions_do_not_exceed_cap(self, make_db):
        db = make_db({})
        admitted_count = 0
        for _ in range(5):
            result = admit_global_request(db, capacity=5, window_seconds=3600)
            if result.admitted:
                admitted_count += 1
        assert admitted_count == 5

        result = admit_global_request(db, capacity=5, window_seconds=3600)
        assert result.rejected is True

    def test_zero_capacity_rejects_all_requests(self, make_db):
        db = make_db({})
        result = admit_global_request(db, capacity=0, window_seconds=3600)
        assert result.admitted is False
        assert result.rejected is True
        assert result.retry_after is None

    def test_negative_capacity_rejects_all_requests(self, make_db):
        db = make_db({})
        result = admit_global_request(db, capacity=-1, window_seconds=3600)
        assert result.admitted is False
        assert result.rejected is True
        assert result.retry_after is None

    def test_shared_state_failure_is_unavailable_not_rejected(self, make_db):
        db = make_db({})
        _break_shared_state(db)

        result = admit_global_request(
            db, capacity=10, window_seconds=3600, fail_closed=True
        )
        assert result.status is AdmissionStatus.UNAVAILABLE
        assert result.unavailable is True
        assert result.rejected is False
        assert result.admitted is False
        assert result.retry_after is None

    def test_fail_open_option(self, make_db):
        db = make_db({})
        _break_shared_state(db)

        result = admit_global_request(
            db, capacity=10, window_seconds=3600, fail_closed=False
        )
        assert result.admitted is True
        assert result.status is AdmissionStatus.ADMITTED


class TestPerCaseRateLimiter:
    def test_first_five_requests_admitted(self, make_db):
        db = make_db({})
        for i in range(5):
            result = admit_case_request(
                db, UID_OWNER, "case-1", max_requests=5, window_seconds=300
            )
            assert result.admitted is True, f"Request {i+1} should be admitted"
            assert result.retry_after is None

    def test_sixth_request_rejected_with_429(self, make_db):
        db = make_db({})
        for _ in range(5):
            admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)

        result = admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)
        assert result.admitted is False
        assert result.rejected is True
        assert result.retry_after is not None
        assert result.retry_after > 0
        assert result.retry_after <= 300

    def test_independent_allowance_by_case(self, make_db):
        db = make_db({})
        for _ in range(5):
            admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)

        result = admit_case_request(db, UID_OWNER, "case-2", max_requests=5, window_seconds=300)
        assert result.admitted is True

    def test_independent_allowance_by_user(self, make_db):
        db = make_db({})
        for _ in range(5):
            admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)

        result = admit_case_request(db, UID_OTHER, "case-1", max_requests=5, window_seconds=300)
        assert result.admitted is True

    def test_window_expiry_allows_new_requests(self, make_db):
        case_key = hashlib.sha256(f"{UID_OWNER}:case-1".encode("utf-8")).hexdigest()
        old_store = {
            ("rate_limits", f"case:{case_key}"): {
                "timestamps": [_past_iso(400)] * 5,
                "updated_at": _past_iso(400),
            }
        }
        db = make_db(old_store)
        result = admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)
        assert result.admitted is True

    def test_rolling_window_filters_old_timestamps(self, make_db):
        case_key = hashlib.sha256(f"{UID_OWNER}:case-1".encode("utf-8")).hexdigest()
        old_store = {
            ("rate_limits", f"case:{case_key}"): {
                "timestamps": [_past_iso(400), _now_iso(), _now_iso()],
                "updated_at": _now_iso(),
            }
        }
        db = make_db(old_store)
        for _ in range(3):
            result = admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)
            assert result.admitted is True
        result = admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)
        assert result.rejected is True

    def test_shared_state_failure_is_unavailable_not_rejected(self, make_db):
        db = make_db({})
        _break_shared_state(db)
        result = admit_case_request(
            db, UID_OWNER, "case-1", max_requests=5, window_seconds=300, fail_closed=True
        )
        assert result.status is AdmissionStatus.UNAVAILABLE
        assert result.unavailable is True
        assert result.rejected is False

    def test_fail_open_option(self, make_db):
        db = make_db({})
        _break_shared_state(db)
        result = admit_case_request(
            db, UID_OWNER, "case-1", max_requests=5, window_seconds=300, fail_closed=False
        )
        assert result.admitted is True
        assert result.status is AdmissionStatus.ADMITTED

    def test_rejected_request_not_counted(self, make_db):
        db = make_db({})
        for _ in range(5):
            admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)
        result = admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)
        assert result.rejected is True
        result = admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)
        assert result.rejected is True

    def test_different_users_independent_counters(self, make_db):
        db = make_db({})
        for _ in range(5):
            admit_case_request(db, UID_OWNER, "case-1", max_requests=5, window_seconds=300)
        result = admit_case_request(db, UID_OTHER, "case-1", max_requests=5, window_seconds=300)
        assert result.admitted is True