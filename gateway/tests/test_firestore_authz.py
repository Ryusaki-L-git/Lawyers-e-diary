"""Tests for gateway/firestore_authz.py — case ownership, subscription,
team access, CNR validation, and transactional race protection."""

from __future__ import annotations

from fastapi import HTTPException
import pytest

from gateway.firestore_authz import (
    AuthorizationError,
    read_case_and_authorize,
    reauthorize_and_update,
)

OWNER_UID = "uid-owner"
OTHER_UID = "uid-other"
CASE_ID = "case-1"
CNR = "ABCD1234EFGH5678"


def _base_store(tier: str = "cloud_subscriber"):
    return {
        ("cases", CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": CNR},
        ("users", OWNER_UID): {"subscription": {"tier": tier}},
    }


def test_owner_with_cloud_subscription_is_authorized(make_db):
    db = make_db(_base_store())
    access = read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert access.case_id == CASE_ID
    assert access.cnr == CNR


def test_legacy_user_id_owner_is_authorized(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {"userId": OWNER_UID, "cnrNumber": CNR},
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    access = read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert access.cnr == CNR


def test_free_tier_is_rejected(make_db):
    db = make_db(_base_store(tier="free"))
    with pytest.raises(HTTPException) as exc:
        read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert exc.value.status_code == 403


def test_missing_subscription_is_rejected(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": CNR},
            ("users", OWNER_UID): {},
        }
    )
    with pytest.raises(HTTPException) as exc:
        read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert exc.value.status_code == 403


def test_case_not_found_is_404(make_db):
    db = make_db(_base_store())
    with pytest.raises(HTTPException) as exc:
        read_case_and_authorize(db, OWNER_UID, "does-not-exist")
    assert exc.value.status_code == 404


def test_cuid_is_canonical_identity(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {
                "ownerUid": OWNER_UID,
                "cuid": CNR.lower(),
                "cnrNumber": CNR,
            },
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    access = read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert access.cnr == CNR


def test_conflicting_cuid_and_cnr_are_rejected(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {
                "ownerUid": OWNER_UID,
                "cuid": "ZZZZ1234EFGH5678",
                "cnrNumber": CNR,
            },
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    with pytest.raises(HTTPException) as exc:
        read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert exc.value.status_code == 409
    assert "do not match" in exc.value.detail


def test_case_without_cnr_is_409(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {"ownerUid": OWNER_UID},
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    with pytest.raises(HTTPException) as exc:
        read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert exc.value.status_code == 409


def test_invalid_cnr_is_409(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": "short"},
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    with pytest.raises(HTTPException) as exc:
        read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert exc.value.status_code == 409


def test_assigned_user_on_non_team_case_is_authorized(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {
                "ownerUid": OTHER_UID,
                "userId": OTHER_UID,
                "assignedTo": OWNER_UID,
                "cnrNumber": CNR,
            },
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    access = read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert access.cnr == CNR


def test_non_member_on_team_case_is_rejected(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {
                "ownerUid": OTHER_UID,
                "teamId": "team-1",
                "assignedTo": OTHER_UID,
                "cnrNumber": CNR,
            },
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
            ("teams", "team-1"): {"ownerId": OTHER_UID, "isActive": True},
            ("teams/team-1/members", OTHER_UID): {"isActive": True},
        }
    )
    with pytest.raises(HTTPException) as exc:
        read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert exc.value.status_code == 403


def test_active_team_member_is_authorized(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {
                "ownerUid": OTHER_UID,
                "teamId": "team-1",
                "assignedTo": OWNER_UID,
                "cnrNumber": CNR,
            },
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
            ("teams", "team-1"): {"ownerId": OTHER_UID, "isActive": True},
            ("teams/team-1/members", OWNER_UID): {"isActive": True},
        }
    )
    access = read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert access.cnr == CNR


def test_inactive_team_member_is_rejected(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {
                "ownerUid": OTHER_UID,
                "teamId": "team-1",
                "assignedTo": OWNER_UID,
                "cnrNumber": CNR,
            },
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
            ("teams", "team-1"): {"ownerId": OTHER_UID, "isActive": True},
            ("teams/team-1/members", OWNER_UID): {"isActive": False},
        }
    )
    with pytest.raises(HTTPException) as exc:
        read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert exc.value.status_code == 403


def test_team_owner_without_assignment_is_authorized(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {
                "ownerUid": OWNER_UID,
                "teamId": "team-1",
                "assignedTo": OTHER_UID,
                "cnrNumber": CNR,
            },
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
            ("teams", "team-1"): {"ownerId": OWNER_UID, "isActive": True},
        }
    )
    access = read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert access.cnr == CNR


def test_team_doc_missing_assigned_user_still_authorized(make_db):
    """H-2: Missing team document falls through to assigned-user check."""
    db = make_db(
        {
            ("cases", CASE_ID): {
                "ownerUid": OTHER_UID,
                "teamId": "dangling-team",
                "assignedTo": OWNER_UID,
                "cnrNumber": CNR,
            },
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    access = read_case_and_authorize(db, OWNER_UID, CASE_ID)
    assert access.cnr == CNR


def test_email_matched_team_member_is_authorized():
    """H-3: Verified-email team member without uid doc is authorized."""
    from gateway.firestore_authz import _is_authorized_case_user
    from types import SimpleNamespace

    case_data = {
        "ownerUid": OTHER_UID,
        "teamId": "team-1",
        "assignedTo": OWNER_UID,
        "cnrNumber": CNR,
    }

    class MockRef:
        def __init__(self, path, doc_id):
            self.path = path
            self.id = doc_id

        def collection(self, name):
            return MockColl(f"{self.path}/{name}")

    class MockColl:
        def __init__(self, name):
            self.name = name

        def document(self, doc_id):
            return MockRef(f"{self.name}/{doc_id}", doc_id)

    class MockDb:
        def collection(self, name):
            return MockColl(name)

    db = MockDb()

    def get_fn(ref):
        snap = SimpleNamespace()
        if ref.path == "teams/team-1":
            snap.exists = True
            snap.to_dict = lambda: {"ownerId": OTHER_UID, "isActive": True}
        elif ref.path == f"teams/team-1/members/{OWNER_UID}":
            snap.exists = False
        else:
            snap.exists = False
        return snap

    def get_members_fn():
        snap = SimpleNamespace()
        snap.exists = True
        snap.to_dict = lambda: {"email": "owner@example.com", "isActive": True}
        return [snap]

    result = _is_authorized_case_user(
        db, OWNER_UID, case_data, get_fn,
        auth_email="owner@example.com", email_verified=True,
        get_members_fn=get_members_fn,
    )
    assert result is True


def test_email_matched_member_inactive_is_rejected():
    """H-3: Email-matched member with isActive=false is rejected."""
    from gateway.firestore_authz import _is_authorized_case_user
    from types import SimpleNamespace

    case_data = {
        "ownerUid": OTHER_UID,
        "teamId": "team-1",
        "assignedTo": OWNER_UID,
        "cnrNumber": CNR,
    }

    class MockRef:
        def __init__(self, path, doc_id):
            self.path = path
            self.id = doc_id

        def collection(self, name):
            return MockColl(f"{self.path}/{name}")

    class MockColl:
        def __init__(self, name):
            self.name = name

        def document(self, doc_id):
            return MockRef(f"{self.name}/{doc_id}", doc_id)

    class MockDb:
        def collection(self, name):
            return MockColl(name)

    db = MockDb()

    def get_fn(ref):
        snap = SimpleNamespace()
        if ref.path == "teams/team-1":
            snap.exists = True
            snap.to_dict = lambda: {"ownerId": OTHER_UID, "isActive": True}
        else:
            snap.exists = False
        return snap

    def get_members_fn():
        snap = SimpleNamespace()
        snap.exists = True
        snap.to_dict = lambda: {"email": "owner@example.com", "isActive": False}
        return [snap]

    result = _is_authorized_case_user(
        db, OWNER_UID, case_data, get_fn,
        auth_email="owner@example.com", email_verified=True,
        get_members_fn=get_members_fn,
    )
    assert result is False


def test_reauthorize_update_writes_ecourts_data(make_db):
    db = make_db(_base_store())
    reauthorize_and_update(db, OWNER_UID, CASE_ID, CNR, {"foo": 1})
    assert db._last_txn is not None
    updates = db._last_txn.updates
    assert len(updates) == 1
    path, doc_id, data = updates[0]
    assert path == "cases"
    assert doc_id == CASE_ID
    assert data == {"ecourts_data": {"foo": 1}}


def test_reauthorize_cnr_mismatch_is_409(make_db):
    db = make_db(_base_store())
    with pytest.raises(HTTPException) as exc:
        reauthorize_and_update(db, OWNER_UID, CASE_ID, "DIFFERENT1234567890", {})
    assert exc.value.status_code == 409


def test_reauthorize_case_deleted_is_404(make_db):
    db = make_db(
        {
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    with pytest.raises(HTTPException) as exc:
        reauthorize_and_update(db, OWNER_UID, CASE_ID, CNR, {})
    assert exc.value.status_code == 404


def test_reauthorize_loses_authorization_is_403(make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {"ownerUid": OTHER_UID, "cnrNumber": CNR},
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    with pytest.raises(HTTPException) as exc:
        reauthorize_and_update(db, OWNER_UID, CASE_ID, CNR, {})
    assert exc.value.status_code == 403
