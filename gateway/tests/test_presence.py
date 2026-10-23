"""Tests for gateway/presence.py — session presence tracking."""

from __future__ import annotations

import hashlib
from datetime import datetime, timedelta, timezone

import pytest

from gateway.presence import (
    InvalidSessionId,
    count_unique_active_users,
    heartbeat_session,
    register_session,
    validate_session_id,
)


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _future_iso(seconds_ahead):
    return (datetime.now(timezone.utc) + timedelta(seconds=seconds_ahead)).isoformat()


def _past_iso(seconds_ago):
    return (datetime.now(timezone.utc) - timedelta(seconds=seconds_ago)).isoformat()


class TestPresenceTracking:
    def test_register_session_creates_document(self, make_db):
        db = make_db({})
        session_id = register_session(db, "uid-1", ttl_seconds=300)

        assert session_id is not None
        assert len(session_id) > 0

        # Verify document was stored
        key = ("presence", f"session:{session_id}")
        assert key in db._store
        data = db._store[key]
        assert data["uid_hash"] is not None
        assert data["created_at"] is not None
        assert data["last_heartbeat"] is not None
        assert data["expires_at"] is not None

    def test_register_session_same_uid_different_devices(self, make_db):
        db = make_db({})
        session_1 = register_session(db, "uid-1", "session-device-a", ttl_seconds=300)
        session_2 = register_session(db, "uid-1", "session-device-b", ttl_seconds=300)

        assert session_1 == "session-device-a"
        assert session_2 == "session-device-b"
        assert session_1 != session_2

        # Two sessions, one unique UID
        key_a = ("presence", "session:session-device-a")
        key_b = ("presence", "session:session-device-b")
        assert db._store[key_a]["uid_hash"] == db._store[key_b]["uid_hash"]

    def test_heartbeat_updates_session(self, make_db):
        db = make_db({})
        session_id = register_session(db, "uid-1", ttl_seconds=300)

        original_heartbeat = db._store[("presence", f"session:{session_id}")]["last_heartbeat"]

        # Wait a tiny bit and heartbeat
        import time
        time.sleep(0.01)
        result = heartbeat_session(db, session_id, "uid-1", ttl_seconds=300)

        assert result is True
        updated_heartbeat = db._store[("presence", f"session:{session_id}")]["last_heartbeat"]
        assert updated_heartbeat >= original_heartbeat

    def test_heartbeat_nonexistent_session_returns_false(self, make_db):
        db = make_db({})
        result = heartbeat_session(db, "nonexistent-session", "uid-1", ttl_seconds=300)
        assert result is False

    def test_heartbeat_ownership_mismatch_returns_false(self, make_db):
        db = make_db({})
        session_id = register_session(db, "uid-1", ttl_seconds=300)

        # Different user tries to heartbeat uid-1's session
        result = heartbeat_session(db, session_id, "uid-2", ttl_seconds=300)
        assert result is False

        # Session data should be unchanged
        key = ("presence", f"session:{session_id}")
        assert db._store[key]["uid_hash"] == hashlib.sha256("uid-1".encode("utf-8")).hexdigest()

    def test_count_unique_active_users_deduplicates_by_uid(self, make_db):
        db = make_db({})
        now = datetime.now(timezone.utc)

        # Two sessions for uid-1 (different devices)
        register_session(db, "uid-1", "session-a", ttl_seconds=300)
        register_session(db, "uid-1", "session-b", ttl_seconds=300)
        # One session for uid-2
        register_session(db, "uid-2", "session-c", ttl_seconds=300)

        count = count_unique_active_users(db, ttl_seconds=300)
        assert count == 2  # Two unique UIDs, not three sessions

    def test_expired_sessions_not_counted(self, make_db):
        db = make_db({})
        # Register a session with short TTL, then expire it manually
        register_session(db, "uid-1", "session-expired", ttl_seconds=1)

        # Directly set expires_at to the past
        key = ("presence", "session:session-expired")
        db._store[key]["expires_at"] = _past_iso(60)

        count = count_unique_active_users(db, ttl_seconds=300)
        assert count == 0

    def test_count_unique_active_users_empty(self, make_db):
        db = make_db({})
        count = count_unique_active_users(db, ttl_seconds=300)
        assert count == 0


class TestSessionIdValidation:
    """Session identifiers must be validated before a Firestore document
    path is constructed."""

    def test_valid_session_id_is_accepted(self):
        assert validate_session_id("abc-123") == "abc-123"
        assert validate_session_id("  padded  ") == "padded"

    def test_server_generated_session_id_is_valid(self, make_db):
        db = make_db({})
        session_id = register_session(db, "uid-1", ttl_seconds=300)
        assert validate_session_id(session_id) == session_id

    def test_slash_is_rejected(self):
        with pytest.raises(InvalidSessionId):
            validate_session_id("a/b")

    def test_empty_is_rejected(self):
        with pytest.raises(InvalidSessionId):
            validate_session_id("   ")

    def test_dot_segments_are_rejected(self):
        with pytest.raises(InvalidSessionId):
            validate_session_id("..")

    def test_control_characters_are_rejected(self):
        with pytest.raises(InvalidSessionId):
            validate_session_id("bad\x00id")

    def test_overlong_is_rejected(self):
        with pytest.raises(InvalidSessionId):
            validate_session_id("a" * 129)

    def test_non_string_is_rejected(self):
        with pytest.raises(InvalidSessionId):
            validate_session_id(None)

    def test_heartbeat_rejects_malformed_session_id(self, make_db):
        db = make_db({})
        with pytest.raises(InvalidSessionId):
            heartbeat_session(db, "a/b", "uid-1", ttl_seconds=300)

    def test_heartbeat_malformed_id_creates_no_document(self, make_db):
        db = make_db({})
        with pytest.raises(InvalidSessionId):
            heartbeat_session(db, "a/b", "uid-1", ttl_seconds=300)
        assert db._store == {}

    def test_register_rejects_malformed_session_id(self, make_db):
        db = make_db({})
        with pytest.raises(InvalidSessionId):
            register_session(db, "uid-1", "a/b", ttl_seconds=300)
        assert db._store == {}
