"""Session presence tracking for the LED eCourts gateway.

Provides lightweight session-presence infrastructure used to estimate the
number of unique active users for the global capacity cap.

Firestore model:
  presence/sessions/{session_id}
    uid_hash: SHA-256 of the verified Firebase UID (never raw UID)
    created_at: ISO-8601 timestamp when the session was first registered
    last_heartbeat: ISO-8601 timestamp of the most recent heartbeat
    expires_at: ISO-8601 timestamp when the session expires (no renewal)

Presence is approximate: an app can be suspended, lose connectivity, or
terminate without notifying the backend. Stale sessions expire through
the expires_at mechanism rather than explicit disconnect notification.

Clients cannot modify other users' sessions because the gateway extracts
the UID from the verified Firebase ID token, never from client input.
"""

from __future__ import annotations

import hashlib
import logging
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from google.cloud.firestore_v1 import transaction as firestore_transaction

logger = logging.getLogger("ecourts_gateway")

_PRESENCE_COLLECTION = "presence"
_SESSION_DOC_PREFIX = "session:"

# Firestore document identifiers must not contain "/" and must be bounded in
# length. Session identifiers are server-generated UUID4 values, so a
# well-formed identifier is a short opaque token. Anything else is rejected
# before a Firestore document path is constructed.
_MAX_SESSION_ID_LENGTH = 128


class InvalidSessionId(ValueError):
    """Raised when a session identifier is malformed.

    The caller is expected to translate this into HTTP 400. It is raised
    before any Firestore document path is constructed so a malformed
    identifier can never reach the Firestore SDK.
    """


def validate_session_id(session_id: str) -> str:
    """Validate a session identifier and return its canonical form.

    Raises InvalidSessionId when the identifier is not a safe, bounded,
    opaque token.
    """
    if not isinstance(session_id, str):
        raise InvalidSessionId("Session identifier must be a string.")

    candidate = session_id.strip()
    if not candidate:
        raise InvalidSessionId("Session identifier must not be empty.")
    if len(candidate) > _MAX_SESSION_ID_LENGTH:
        raise InvalidSessionId("Session identifier is too long.")
    if "/" in candidate:
        raise InvalidSessionId("Session identifier must not contain '/'.")
    if candidate in (".", ".."):
        raise InvalidSessionId("Session identifier is not a valid identifier.")
    if any(ord(ch) < 0x20 or ord(ch) == 0x7F for ch in candidate):
        raise InvalidSessionId("Session identifier contains control characters.")
    return candidate


def _uid_hash(uid: str) -> str:
    """Return a SHA-256 hash of the UID for use as a Firestore field value."""
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


def register_session(
    db,
    uid: str,
    session_id: Optional[str] = None,
    ttl_seconds: int = 300,
) -> str:
    """Register or update a presence session for a verified user.

    Returns the session ID (caller-provided or newly generated).

    If the same session_id already exists and belongs to the same uid_hash,
    updates last_heartbeat and expires_at. If a different session_id is
    provided, creates a new session document. Each device/install gets its
    own session document, but all sessions for the same UID share the same
    uid_hash, so counting unique UIDs deduplicates multi-device users.

    If session_id is provided but already belongs to a different user, the
    existing session is left untouched and the caller-provided session_id is
    returned unchanged (no ownership transfer).

    Session identifiers remain server-generated. A caller-supplied
    identifier is validated before any Firestore document path is built.
    """
    if session_id is None:
        session_id = str(uuid.uuid4())
    else:
        session_id = validate_session_id(session_id)

    doc_ref = db.collection(_PRESENCE_COLLECTION).document(
        f"{_SESSION_DOC_PREFIX}{session_id}"
    )
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(seconds=ttl_seconds)
    target_uid_hash = _uid_hash(uid)

    doc = doc_ref.get()
    if doc.exists:
        existing_data = doc.to_dict() or {}
        existing_uid_hash = existing_data.get("uid_hash")
        if existing_uid_hash is not None and existing_uid_hash != target_uid_hash:
            # Session belongs to a different user; do not transfer ownership.
            return session_id

    doc_ref.set(
        {
            "uid_hash": target_uid_hash,
            "created_at": _now_iso(),
            "last_heartbeat": _now_iso(),
            "expires_at": expires_at.isoformat(),
        },
        merge=True,
    )

    return session_id


def heartbeat_session(
    db,
    session_id: str,
    uid: str,
    ttl_seconds: int = 300,
) -> bool:
    """Refresh a session's heartbeat and expiration.

    Returns True if the session exists, belongs to the given uid, and was
    updated. Returns False if the session does not exist or belongs to a
    different user (ownership mismatch).

    Raises InvalidSessionId when the identifier is malformed. The check
    happens before the Firestore document path is constructed.
    """
    session_id = validate_session_id(session_id)

    doc_ref = db.collection(_PRESENCE_COLLECTION).document(
        f"{_SESSION_DOC_PREFIX}{session_id}"
    )
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(seconds=ttl_seconds)
    target_uid_hash = _uid_hash(uid)

    doc = doc_ref.get()
    if not doc.exists:
        return False

    existing_data = doc.to_dict() or {}
    existing_uid_hash = existing_data.get("uid_hash")
    if existing_uid_hash is not None and existing_uid_hash != target_uid_hash:
        # Ownership mismatch: session belongs to a different user.
        return False

    doc_ref.update(
        {
            "last_heartbeat": _now_iso(),
            "expires_at": expires_at.isoformat(),
        }
    )
    return True


def count_unique_active_users(db, ttl_seconds: int = 300) -> int:
    """Count unique verified Firebase UIDs with active (non-expired) sessions.

    Queries presence sessions where expires_at > now, then deduplicates
    by uid_hash so a user with multiple devices is counted once.

    This is a Firestore query (not a transaction), so it provides an
    approximate count. Use the result to stabilize the global capacity
    for an accounting window.
    """
    now = datetime.now(timezone.utc)
    expiry_cutoff = now.isoformat()

    sessions_ref = db.collection(_PRESENCE_COLLECTION)
    query = sessions_ref.where("expires_at", ">", expiry_cutoff)
    docs = query.get()

    unique_uids = set()
    for doc in docs:
        data = doc.to_dict() or {}
        uid_hash = data.get("uid_hash")
        if uid_hash:
            unique_uids.add(uid_hash)

    return len(unique_uids)


def cleanup_expired_sessions(db, ttl_seconds: int = 300) -> int:
    """Remove expired presence sessions. Returns the count removed.

    This is a best-effort cleanup; sessions also expire naturally through
    the expires_at filter in count_unique_active_users.
    """
    now = datetime.now(timezone.utc)
    expiry_cutoff = now.isoformat()

    sessions_ref = db.collection(_PRESENCE_COLLECTION)
    query = sessions_ref.where("expires_at", "<", expiry_cutoff)
    docs = query.get()

    removed = 0
    for doc in docs:
        doc.reference.delete()
        removed += 1

    return removed
