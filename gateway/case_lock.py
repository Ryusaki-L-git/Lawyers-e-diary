"""Per-case concurrency protection for the LED eCourts gateway.

Prevents overlapping refresh requests for the same case using a
Firestore-backed lock with a unique owner token and TTL.

Firestore model:
  case_locks/{case_id}
    lock_token: unique UUID identifying the holder of the lock
    acquired_at: ISO-8601 timestamp when the lock was acquired
    expires_at: ISO-8601 timestamp when the lock expires (crash recovery)

Design properties:
- Each lock has a unique owner/token; an expired or old request cannot
  release a newer request's lock (token comparison on release).
- The lock has a TTL; if the holder crashes, the lock expires and the
  case becomes available again.
- The lock is released in all normal success and error paths (try/finally).
- The lock does NOT make the provider request idempotent; it only
  prevents concurrent refresh operations for the same case.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from .admission import AdmissionResult

logger = logging.getLogger("ecourts_gateway")

_CASE_LOCK_COLLECTION = "case_locks"


def _parse_iso(iso_str: str) -> datetime:
    """Parse an ISO-8601 datetime string, returning a timezone-aware datetime."""
    dt = datetime.fromisoformat(iso_str)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def _now_iso() -> str:
    """Return the current UTC time as an ISO-8601 string."""
    return datetime.now(timezone.utc).isoformat()


def acquire_case_lock(
    db,
    case_id: str,
    lock_token: Optional[str] = None,
    ttl_seconds: int = 30,
) -> AdmissionResult:
    """Attempt to acquire a per-case concurrency lock.

    Returns an AdmissionResult:
      - ADMITTED    when the lock was acquired (or is already held by this
                    same token).
      - REJECTED    when another request holds an active lock. `retry_after`
                    holds the seconds until that lock expires when it can be
                    determined reliably.
      - UNAVAILABLE when the shared state could not be consulted. The lock
                    always fails closed, so the caller must report this as an
                    infrastructure failure (HTTP 503), never as a rate-limit
                    rejection.

    Uses a Firestore transaction so the check-and-acquire is atomic
    across multiple gateway instances.
    """
    if lock_token is None:
        lock_token = str(uuid.uuid4())

    doc_ref = db.collection(_CASE_LOCK_COLLECTION).document(case_id)

    def _acquire(transaction):
        now = datetime.now(timezone.utc)
        doc = transaction.get(doc_ref)

        if doc.exists:
            data = doc.to_dict() or {}
            try:
                expires_at = _parse_iso(data.get("expires_at", _now_iso()))
            except (ValueError, TypeError):
                expires_at = now

            if now < expires_at:
                # Lock is active and held by another request.
                existing_token = data.get("lock_token")
                if existing_token == lock_token:
                    # Same token already holds the lock (re-entrant).
                    return AdmissionResult.admit()
                retry_after = int((expires_at - now).total_seconds())
                if retry_after < 1:
                    retry_after = 1
                return AdmissionResult.reject(retry_after)
            # Lock expired; acquire it.
        transaction.set(
            doc_ref,
            {
                "lock_token": lock_token,
                "acquired_at": _now_iso(),
                "expires_at": (now + timedelta(seconds=ttl_seconds)).isoformat(),
            },
        )
        return AdmissionResult.admit()

    try:
        result = [None]
        db.run_transaction(lambda txn: result.__setitem__(0, _acquire(txn)))
        return result[0]
    except Exception as exc:  # noqa: BLE001
        logger.exception("Case lock shared-state failure")
        # Fail closed: cannot safely proceed without a lock.
        return AdmissionResult.unavailable_result()


def release_case_lock(
    db,
    case_id: str,
    lock_token: str,
) -> None:
    """Release a per-case concurrency lock if held by the given token.

    Safe to call even if the lock was already released or expired; the
    token comparison ensures we never release another request's lock.
    """
    doc_ref = db.collection(_CASE_LOCK_COLLECTION).document(case_id)

    def _release(transaction):
        doc = transaction.get(doc_ref)
        if not doc.exists:
            return
        data = doc.to_dict() or {}
        if data.get("lock_token") == lock_token:
            transaction.delete(doc_ref)

    try:
        db.run_transaction(_release)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Case lock release failed; lock will expire via TTL")
