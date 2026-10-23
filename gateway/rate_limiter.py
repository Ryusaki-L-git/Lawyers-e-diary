"""Rate limiter for the LED eCourts gateway.

Implements two shared, atomic protections using Firestore transactions:

1. Per-user admission limit: 5 admitted refresh attempts per verified
   Firebase UID per rolling 10-minute window. Uses SHA-256 of the UID
   as the document key to avoid storing PII in Firestore.

2. Global capacity cap: estimated unique active users × capacity
   multiplier, enforced as a shared atomic counter across all gateway
   instances. Capacity is stabilized at the start of each accounting
   window and does not change during the window.

All state is stored in Firestore, so limits are enforced consistently
across multiple gateway instances and survive instance restarts.
"""

from __future__ import annotations

import hashlib
import logging
from datetime import datetime, timedelta, timezone

from .admission import AdmissionResult

logger = logging.getLogger("ecourts_gateway")

# Firestore collection paths
_RATE_LIMIT_COLLECTION = "rate_limits"
_USER_LIMIT_DOC_PREFIX = "user:"
_CASE_LIMIT_DOC_PREFIX = "case:"
_GLOBAL_CAPACITY_DOC_ID = "global:capacity"


def _uid_hash(uid: str) -> str:
    """Return a SHA-256 hash of the UID for use as a Firestore document key.

    Never stores raw UIDs in Firestore to avoid exposing personal data.
    """
    return hashlib.sha256(uid.encode("utf-8")).hexdigest()


def _parse_iso(iso_str: str) -> datetime:
    """Parse an ISO-8601 datetime string, returning a timezone-aware datetime."""
    dt = datetime.fromisoformat(iso_str)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _now_iso() -> str:
    """Return the current UTC time as an ISO-8601 string."""
    return datetime.now(timezone.utc).isoformat()


# ---------------------------------------------------------------------------
# Per-user admission limit
# ---------------------------------------------------------------------------

def admit_user_request(
    db,
    uid: str,
    max_requests: int,
    window_seconds: int,
    fail_closed: bool = True,
) -> AdmissionResult:
    """Atomically admit or reject a refresh request for a user.

    Uses a Firestore transaction so the check-and-increment is atomic
    across multiple gateway instances.

    Returns an AdmissionResult:
      - ADMITTED    when the request may proceed.
      - REJECTED    when the rolling window already holds `max_requests`
                    admitted attempts. `retry_after` holds the number of
                    seconds until the next eligible attempt when it can be
                    determined reliably.
      - UNAVAILABLE when the shared state could not be consulted and
                    fail-closed behaviour is enabled. The caller must report
                    this as an infrastructure failure (HTTP 503), never as a
                    rate-limit rejection.
    """
    doc_ref = db.collection(_RATE_LIMIT_COLLECTION).document(
        f"{_USER_LIMIT_DOC_PREFIX}{_uid_hash(uid)}"
    )

    def _admit(transaction):
        now = datetime.now(timezone.utc)
        doc = transaction.get(doc_ref)

        if doc.exists:
            data = doc.to_dict() or {}
            raw_timestamps = data.get("timestamps", [])
            valid_timestamps = []
            for ts_str in raw_timestamps:
                try:
                    ts = _parse_iso(ts_str)
                    if (now - ts).total_seconds() < window_seconds:
                        valid_timestamps.append(ts_str)
                except (ValueError, TypeError):
                    continue

            if len(valid_timestamps) >= max_requests:
                # Window not expired; compute retry-after from oldest timestamp.
                oldest = min(_parse_iso(ts) for ts in valid_timestamps)
                retry_after = int(
                    (oldest + timedelta(seconds=window_seconds) - now).total_seconds()
                )
                if retry_after < 1:
                    retry_after = 1
                return AdmissionResult.reject(retry_after)

            # Admit: append current timestamp, overwrite with only valid ones.
            valid_timestamps.append(_now_iso())
            transaction.update(
                doc_ref,
                {
                    "timestamps": valid_timestamps,
                    "updated_at": _now_iso(),
                },
            )
        else:
            transaction.set(
                doc_ref,
                {
                    "timestamps": [_now_iso()],
                    "updated_at": _now_iso(),
                },
            )

        return AdmissionResult.admit()

    try:
        result = [None]
        db.run_transaction(lambda txn: result.__setitem__(0, _admit(txn)))
        return result[0]
    except Exception as exc:  # noqa: BLE001
        logger.exception("Per-user rate limiter shared-state failure")
        if fail_closed:
            return AdmissionResult.unavailable_result()
        return AdmissionResult.admit()


# ---------------------------------------------------------------------------
# Per-case admission limit
# ---------------------------------------------------------------------------


def _case_key(uid: str, case_id: str) -> str:
    """Return a SHA-256 hash of uid+case_id for use as a Firestore document key.

    Never stores raw UIDs or case IDs in Firestore to avoid exposing personal
    data or case identifiers.
    """
    return hashlib.sha256(f"{uid}:{case_id}".encode("utf-8")).hexdigest()


def admit_case_request(
    db,
    uid: str,
    case_id: str,
    max_requests: int,
    window_seconds: int,
    fail_closed: bool = True,
) -> AdmissionResult:
    """Atomically admit or reject a refresh request for a user-case pair.

    Uses a Firestore transaction so the check-and-increment is atomic
    across multiple gateway instances.

    Returns an AdmissionResult:
      - ADMITTED    when the request may proceed.
      - REJECTED    when the rolling window already holds `max_requests`
                    admitted attempts for this user-case pair. `retry_after`
                    holds the number of seconds until the next eligible
                    attempt when it can be determined reliably.
      - UNAVAILABLE when the shared state could not be consulted and
                    fail-closed behaviour is enabled. The caller must report
                    this as an infrastructure failure (HTTP 503), never as a
                    rate-limit rejection.
    """
    doc_ref = db.collection(_RATE_LIMIT_COLLECTION).document(
        f"{_CASE_LIMIT_DOC_PREFIX}{_case_key(uid, case_id)}"
    )

    def _admit(transaction):
        now = datetime.now(timezone.utc)
        doc = transaction.get(doc_ref)

        if doc.exists:
            data = doc.to_dict() or {}
            raw_timestamps = data.get("timestamps", [])
            valid_timestamps = []
            for ts_str in raw_timestamps:
                try:
                    ts = _parse_iso(ts_str)
                    if (now - ts).total_seconds() < window_seconds:
                        valid_timestamps.append(ts_str)
                except (ValueError, TypeError):
                    continue

            if len(valid_timestamps) >= max_requests:
                oldest = min(_parse_iso(ts) for ts in valid_timestamps)
                retry_after = int(
                    (oldest + timedelta(seconds=window_seconds) - now).total_seconds()
                )
                if retry_after < 1:
                    retry_after = 1
                return AdmissionResult.reject(retry_after)

            valid_timestamps.append(_now_iso())
            transaction.update(
                doc_ref,
                {
                    "timestamps": valid_timestamps,
                    "updated_at": _now_iso(),
                },
            )
        else:
            transaction.set(
                doc_ref,
                {
                    "timestamps": [_now_iso()],
                    "updated_at": _now_iso(),
                },
            )

        return AdmissionResult.admit()

    try:
        result = [None]
        db.run_transaction(lambda txn: result.__setitem__(0, _admit(txn)))
        return result[0]
    except Exception as exc:  # noqa: BLE001
        logger.exception("Per-case rate limiter shared-state failure")
        if fail_closed:
            return AdmissionResult.unavailable_result()
        return AdmissionResult.admit()


# ---------------------------------------------------------------------------
# Global capacity cap
# ---------------------------------------------------------------------------

def admit_global_request(
    db,
    capacity: int,
    window_seconds: int,
    fail_closed: bool = True,
) -> AdmissionResult:
    """Atomically admit or reject a request against the global capacity cap.

    Capacity is set at the start of each accounting window and does not
    change during the window. Uses a Firestore transaction for atomic
    check-and-increment across instances.

    Returns an AdmissionResult:
      - ADMITTED    when the request may proceed.
      - REJECTED    when the current window has consumed its capacity.
                    `retry_after` holds the seconds until the window resets.
      - UNAVAILABLE when the shared state could not be consulted and
                    fail-closed behaviour is enabled.
    """
    doc_ref = db.collection(_RATE_LIMIT_COLLECTION).document(
        _GLOBAL_CAPACITY_DOC_ID
    )

    def _admit(transaction):
        now = datetime.now(timezone.utc)
        doc = transaction.get(doc_ref)

        # A capacity of 0 means no global allowance is configured;
        # reject every request to avoid silently bypassing enforcement.
        if capacity <= 0:
            return AdmissionResult.reject()

        if doc.exists:
            data = doc.to_dict() or {}
            try:
                window_start = _parse_iso(data.get("window_start", _now_iso()))
            except (ValueError, TypeError):
                window_start = now

            # Check if window has expired.
            if (now - window_start).total_seconds() >= window_seconds:
                transaction.update(
                    doc_ref,
                    {
                        "window_start": _now_iso(),
                        "used": 1,
                        "capacity": capacity,
                    },
                )
                return AdmissionResult.admit()

            used = int(data.get("used", 0))
            stored_capacity = int(data.get("capacity", 0))
            if used >= stored_capacity:
                retry_after = int(
                    (
                        window_start + timedelta(seconds=window_seconds) - now
                    ).total_seconds()
                )
                if retry_after < 1:
                    retry_after = 1
                return AdmissionResult.reject(retry_after)

            transaction.update(doc_ref, {"used": used + 1})
        else:
            transaction.set(
                doc_ref,
                {
                    "window_start": _now_iso(),
                    "used": 1,
                    "capacity": capacity,
                },
            )

        return AdmissionResult.admit()

    try:
        result = [None]
        db.run_transaction(lambda txn: result.__setitem__(0, _admit(txn)))
        return result[0]
    except Exception as exc:  # noqa: BLE001
        logger.exception("Global capacity limiter shared-state failure")
        if fail_closed:
            return AdmissionResult.unavailable_result()
        return AdmissionResult.admit()


def compute_global_capacity(
    estimated_active_users: int,
    capacity_multiplier: int,
) -> int:
    """Compute the global capacity from estimated active users.

    capacity = estimated_active_users × capacity_multiplier

    This is an application-level safety mechanism, not a verified
    provider quota. If estimated_active_users is 0, capacity is 0
    (all requests rejected until presence data is available).
    """
    if estimated_active_users < 0:
        estimated_active_users = 0
    if capacity_multiplier < 1:
        capacity_multiplier = 1
    return estimated_active_users * capacity_multiplier
