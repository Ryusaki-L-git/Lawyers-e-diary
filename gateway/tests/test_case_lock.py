"""Tests for gateway/case_lock.py — per-case concurrency protection."""

from __future__ import annotations

import pytest

from gateway.admission import AdmissionStatus
from gateway.case_lock import acquire_case_lock, release_case_lock


def _break_shared_state(db):
    """Make the shared transaction store unavailable."""

    def failing_run_transaction(work):
        raise Exception("Firestore unavailable")

    db.run_transaction = failing_run_transaction


class TestCaseLock:
    def test_acquire_and_release_lock(self, make_db):
        db = make_db({})
        lock_token = "test-token-123"

        result = acquire_case_lock(db, "case-1", lock_token, ttl_seconds=30)
        assert result.admitted is True
        assert result.status is AdmissionStatus.ADMITTED
        assert result.retry_after is None

        # Verify lock document exists
        key = ("case_locks", "case-1")
        assert key in db._store
        assert db._store[key]["lock_token"] == lock_token

        release_case_lock(db, "case-1", lock_token)

        # Lock should be deleted
        assert key not in db._store

    def test_second_request_cannot_acquire_held_lock(self, make_db):
        db = make_db({})
        token_a = "token-a"
        token_b = "token-b"

        result_a = acquire_case_lock(db, "case-1", token_a, ttl_seconds=30)
        assert result_a.admitted is True

        result_b = acquire_case_lock(db, "case-1", token_b, ttl_seconds=30)
        assert result_b.admitted is False
        assert result_b.rejected is True
        assert result_b.status is AdmissionStatus.REJECTED
        assert result_b.retry_after is not None
        assert result_b.retry_after > 0
        assert result_b.retry_after <= 30

    def test_cannot_release_another_holders_lock(self, make_db):
        db = make_db({})
        token_a = "token-a"
        token_b = "token-b"

        acquire_case_lock(db, "case-1", token_a, ttl_seconds=30)

        # Try to release with wrong token
        release_case_lock(db, "case-1", token_b)

        # Lock should still exist with token_a
        key = ("case_locks", "case-1")
        assert key in db._store
        assert db._store[key]["lock_token"] == token_a

    def test_correct_token_releases_lock(self, make_db):
        db = make_db({})
        token_a = "token-a"

        acquire_case_lock(db, "case-1", token_a, ttl_seconds=30)
        release_case_lock(db, "case-1", token_a)

        key = ("case_locks", "case-1")
        assert key not in db._store

    def test_expired_lock_can_be_reacquired(self, make_db):
        db = make_db({})
        token_a = "token-a"
        token_b = "token-b"

        # Acquire lock with expired TTL
        result_a = acquire_case_lock(db, "case-1", token_a, ttl_seconds=1)
        assert result_a.admitted is True

        # Manually expire the lock
        key = ("case_locks", "case-1")
        from datetime import datetime, timedelta, timezone
        db._store[key]["expires_at"] = (
            datetime.now(timezone.utc) - timedelta(seconds=60)
        ).isoformat()

        # Token B should be able to acquire the expired lock
        result_b = acquire_case_lock(db, "case-1", token_b, ttl_seconds=30)
        assert result_b.admitted is True
        assert db._store[key]["lock_token"] == token_b

    def test_release_nonexistent_lock_is_safe(self, make_db):
        db = make_db({})
        # Should not raise
        release_case_lock(db, "case-nonexistent", "any-token")

    def test_reentrant_same_token(self, make_db):
        db = make_db({})
        token = "reentrant-token"

        result_1 = acquire_case_lock(db, "case-1", token, ttl_seconds=30)
        assert result_1.admitted is True

        result_2 = acquire_case_lock(db, "case-1", token, ttl_seconds=30)
        assert result_2.admitted is True  # Same token re-acquires

        release_case_lock(db, "case-1", token)
        key = ("case_locks", "case-1")
        assert key not in db._store

    def test_shared_state_failure_is_unavailable_not_rejected(self, make_db):
        """A Firestore failure must be UNAVAILABLE, never a lock rejection."""
        db = make_db({})
        _break_shared_state(db)

        result = acquire_case_lock(db, "case-1", "token-a", ttl_seconds=30)
        assert result.status is AdmissionStatus.UNAVAILABLE
        assert result.unavailable is True
        # Explicitly NOT a rate-limit rejection.
        assert result.rejected is False
        assert result.admitted is False
        assert result.retry_after is None
