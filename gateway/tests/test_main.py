"""End-to-end tests for gateway/main.py — route handling, authz, and error mapping."""

from __future__ import annotations

import hashlib
from types import SimpleNamespace

from fastapi.testclient import TestClient
import pytest

import gateway.main as main_mod
from gateway.firestore_authz import AuthorizationError
from gateway.provider import EcourtsProviderError

CASE_ID = "case-1"
CNR = "ABCD1234EFGH5678"
OWNER_UID = "uid-owner"
OTHER_UID = "uid-other"


class MockProvider:
    def __init__(self, data=None, error=None):
        self._data = data or {
            "cnr": CNR,
            "case_number": "C-1",
            "provider": "ecourtsindia",
            "retrieved_at": "2026-01-01T00:00:00+00:00",
        }
        self._error = error
        self.called_with = None

    def refresh(self, cnr):
        self.called_with = cnr
        if self._error is not None:
            raise self._error
        return dict(self._data)


@pytest.fixture
def env(monkeypatch):
    monkeypatch.setenv("FIREBASE_PROJECT_ID", "proj")
    monkeypatch.setenv(
        "FIREBASE_SERVICE_ACCOUNT_JSON",
        '{"type":"service_account","private_key":"x","client_email":"a@b.iam.gserviceaccount.com"}',
    )
    monkeypatch.setenv("ECOURTS_API_KEY", "test-key")
    monkeypatch.setenv("ECOURTS_BASE_URL", "https://example.com")
    monkeypatch.setenv("RATE_LIMIT_USER_MAX_REQUESTS", "5")
    monkeypatch.setenv("RATE_LIMIT_USER_WINDOW_SECONDS", "600")
    monkeypatch.setenv("RATE_LIMIT_CASE_MAX_REQUESTS", "5")
    monkeypatch.setenv("RATE_LIMIT_CASE_WINDOW_SECONDS", "300")
    monkeypatch.setenv("RATE_LIMIT_CAPACITY_MULTIPLIER", "5")
    monkeypatch.setenv("RATE_LIMIT_ZERO_USER_FALLBACK_USERS", "5")
    monkeypatch.setenv("RATE_LIMIT_GLOBAL_WINDOW_SECONDS", "3600")
    monkeypatch.setenv("RATE_LIMIT_CASE_LOCK_TTL_SECONDS", "30")
    monkeypatch.setenv("RATE_LIMIT_FAIL_CLOSED", "true")


@pytest.fixture
def ctx(env, make_db, monkeypatch):
    import firebase_admin.auth

    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda token, check_revoked=False: {"uid": OWNER_UID, "email": "a@b.com", "email_verified": True},
    )

    store = {
        ("cases", CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": CNR},
        ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
    }
    db = make_db(store)
    provider = MockProvider()

    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db
    main_mod.app.dependency_overrides[main_mod.get_provider] = lambda: provider

    yield SimpleNamespace(client=TestClient(main_mod.app), db=db, provider=provider)

    main_mod.app.dependency_overrides.clear()


def _headers(token="tok"):
    return {"Authorization": f"Bearer {token}"}


def test_service_catalogue_is_authenticated_and_marks_services_unavailable_until_billing_is_ready(ctx):
    response = ctx.client.get("/v1/services/catalogue", headers=_headers())
    assert response.status_code == 200, response.text
    items = response.json()
    assert any(item["serviceId"] == "case_detail" and item["tokenPrice"] == 5.0 for item in items)
    refresh = next(item for item in items if item["serviceId"] == "smart_refresh")
    assert refresh["tokenPrice"] == 0.5
    assert refresh["available"] is False
    assert all(item["available"] is False for item in items)


def test_service_catalogue_requires_authentication(ctx):
    response = ctx.client.get("/v1/services/catalogue")
    assert response.status_code == 401


def test_refresh_fails_closed_until_authoritative_billing_is_configured(ctx):
    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 503, response.text
    assert "secure token billing" in response.json()["detail"]
    assert ctx.provider.called_with is None
    case_data = ctx.db._store.get(("cases", CASE_ID))
    assert case_data is not None
    assert "ecourts_data" not in case_data
    assert not [k for k in ctx.db._store if k[0] == "rate_limits"]
    assert not [k for k in ctx.db._store if k[0] == "case_locks"]


def test_refresh_missing_token_is_401(ctx):
    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh")
    assert response.status_code == 401


def test_refresh_invalid_token_is_401(ctx, monkeypatch):
    import firebase_admin.auth

    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda t, check_revoked=False: (_ for _ in ()).throw(Exception("bad")),
    )
    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 401


def test_refresh_not_cloud_subscriber_is_403(ctx, make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": CNR},
            ("users", OWNER_UID): {"subscription": {"tier": "free"}},
        }
    )
    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db
    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 403


def test_refresh_not_authorized_is_403(ctx, make_db):
    db = make_db(
        {
            ("cases", CASE_ID): {"ownerUid": OTHER_UID, "cnrNumber": CNR},
            ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
        }
    )
    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db
    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 403


def test_refresh_case_not_found_is_404(ctx, make_db):
    db = make_db({("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}}})
    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db
    response = ctx.client.post(f"/v1/ecourts/cases/missing/refresh", headers=_headers())
    assert response.status_code == 404


def test_refresh_provider_not_found_does_not_call_provider_before_billing(ctx):
    provider = MockProvider(error=EcourtsProviderError(404, "not found in eCourts"))
    main_mod.app.dependency_overrides[main_mod.get_provider] = lambda: provider
    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 503
    assert provider.called_with is None


def test_refresh_provider_rate_limit_does_not_call_provider_before_billing(ctx):
    provider = MockProvider(error=EcourtsProviderError(429, "rate limited"))
    main_mod.app.dependency_overrides[main_mod.get_provider] = lambda: provider
    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 503
    assert provider.called_with is None


def test_refresh_does_not_call_provider_before_billing(ctx):
    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 503, response.text
    assert ctx.provider.called_with is None


def test_validate_case_id_rejects_traversal():
    from gateway.firestore_authz import _validate_case_id
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as exc:
        _validate_case_id("../evil")
    assert exc.value.status_code == 400


def test_validate_case_id_rejects_slash():
    from gateway.firestore_authz import _validate_case_id
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as exc:
        _validate_case_id("a/b")
    assert exc.value.status_code == 400


def test_validate_case_id_rejects_dot_segments():
    from gateway.firestore_authz import _validate_case_id
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as exc:
        _validate_case_id(".")
    assert exc.value.status_code == 400


def test_validate_case_id_rejects_control_chars():
    from gateway.firestore_authz import _validate_case_id
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as exc:
        _validate_case_id("case\x00id")
    assert exc.value.status_code == 400


def test_validate_case_id_accepts_valid_id():
    from gateway.firestore_authz import _validate_case_id

    assert _validate_case_id("case-123") == "case-123"
    assert _validate_case_id("  case-123  ") == "case-123"


def test_healthz_returns_ok_without_case_data(ctx):
    response = ctx.client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert "ecourts" not in response.text
    assert "provider" not in response.text


def test_healthz(ctx):
    response = ctx.client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_global_cap_fail_closed_when_no_estimate(ctx, make_db, monkeypatch):
    db = make_db({
        ("cases", CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": CNR},
        ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
    })
    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db
    monkeypatch.setenv("RATE_LIMIT_ESTIMATED_ACTIVE_USERS", "0")
    monkeypatch.setenv("RATE_LIMIT_ZERO_USER_FALLBACK_USERS", "0")

    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 503, response.text


def test_zero_user_fallback_provides_capacity(ctx, make_db, monkeypatch):
    db = make_db({
        ("cases", CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": CNR},
        ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
    })
    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db
    monkeypatch.setenv("RATE_LIMIT_ESTIMATED_ACTIVE_USERS", "0")
    monkeypatch.setenv("RATE_LIMIT_ZERO_USER_FALLBACK_USERS", "5")

    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 200, response.text


def test_per_case_limit_exceeded_is_429(ctx, monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_USER_MAX_REQUESTS", "50")
    for _ in range(5):
        response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
        assert response.status_code == 200, response.text

    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 429, response.text
    assert "Per-case refresh limit reached" in response.json()["detail"]


def test_per_case_independent_by_case(ctx, make_db, monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_USER_MAX_REQUESTS", "50")
    OTHER_CASE_ID = "case-2"
    db = make_db({
        ("cases", CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": CNR},
        ("cases", OTHER_CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": CNR},
        ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
    })
    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db

    for _ in range(5):
        response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
        assert response.status_code == 200, response.text

    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 429, response.text
    assert "Per-case refresh limit reached" in response.json()["detail"]

    response = ctx.client.post(f"/v1/ecourts/cases/{OTHER_CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 200, response.text


def test_unauthorized_request_does_not_consume_rate_limit(ctx, make_db):
    db = make_db({
        ("cases", CASE_ID): {"ownerUid": OTHER_UID, "cnrNumber": CNR},
        ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
    })
    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db

    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 403

    rate_docs = [k for k in db._store if k[0] == "rate_limits"]
    uid_hash = hashlib.sha256(OWNER_UID.encode("utf-8")).hexdigest()
    assert not any(k[1] == f"user:{uid_hash}" for k in rate_docs)

    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 403

    rate_docs = [k for k in db._store if k[0] == "rate_limits"]
    assert not any(k[1] == f"user:{uid_hash}" for k in rate_docs)


def test_case_lock_retry_after_header(ctx):
    db = ctx.db
    from gateway.case_lock import acquire_case_lock
    acquire_case_lock(db, CASE_ID, "holder-token", ttl_seconds=30)

    response = ctx.client.post(f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers())
    assert response.status_code == 429, response.text
    assert "Retry-After" in response.headers, "Lock rejection should include Retry-After"
    retry_after = int(response.headers["Retry-After"])
    assert 1 <= retry_after <= 30, f"Retry-After {retry_after} out of expected range"


def test_register_presence_ownership_protection(ctx, make_db):
    from gateway.presence import register_session
    import hashlib

    db = make_db({})
    session_id = register_session(db, "uid-1", "session-abc", ttl_seconds=300)
    key = ("presence", "session:session-abc")
    assert db._store[key]["uid_hash"] == hashlib.sha256("uid-1".encode("utf-8")).hexdigest()

    session_id_returned = register_session(db, "uid-2", "session-abc", ttl_seconds=300)
    assert session_id_returned == "session-abc"

    assert db._store[key]["uid_hash"] == hashlib.sha256("uid-1".encode("utf-8")).hexdigest()


def _fail_transaction_on_call(db, call_index):
    original = db.run_transaction
    state = {"calls": 0}

    def wrapper(work):
        state["calls"] += 1
        if state["calls"] == call_index:
            raise Exception("Firestore unavailable")
        return original(work)

    db.run_transaction = wrapper


def test_per_user_limiter_shared_state_failure_is_503(ctx):
    _fail_transaction_on_call(ctx.db, 1)

    response = ctx.client.post(
        f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers()
    )
    assert response.status_code == 503, response.text
    assert response.status_code != 429
    assert "Retry-After" not in response.headers
    assert ctx.provider.called_with is None


def test_case_lock_shared_state_failure_is_503(ctx):
    _fail_transaction_on_call(ctx.db, 2)

    response = ctx.client.post(
        f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers()
    )
    assert response.status_code == 503, response.text
    assert response.status_code != 429
    assert ctx.provider.called_with is None


def test_global_cap_shared_state_failure_is_503(ctx):
    _fail_transaction_on_call(ctx.db, 3)

    response = ctx.client.post(
        f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers()
    )
    assert response.status_code == 503, response.text
    assert response.status_code != 429
    assert ctx.provider.called_with is None


def test_per_user_limit_exceeded_is_429_not_503(ctx):
    for _ in range(5):
        response = ctx.client.post(
            f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers()
        )
        assert response.status_code == 200, response.text

    response = ctx.client.post(
        f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers()
    )
    assert response.status_code == 429, response.text
    assert "Retry-After" in response.headers
    assert int(response.headers["Retry-After"]) > 0
    assert "Per-user refresh limit reached" in response.json()["detail"]


def test_global_capacity_exceeded_is_429_not_503(ctx, make_db, monkeypatch):
    monkeypatch.setenv("RATE_LIMIT_USER_MAX_REQUESTS", "50")
    monkeypatch.setenv("RATE_LIMIT_CASE_MAX_REQUESTS", "50")
    monkeypatch.setenv("RATE_LIMIT_ZERO_USER_FALLBACK_USERS", "1")

    db = make_db({
        ("cases", CASE_ID): {"ownerUid": OWNER_UID, "cnrNumber": CNR},
        ("users", OWNER_UID): {"subscription": {"tier": "cloud_subscriber"}},
    })
    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db

    for _ in range(5):
        response = ctx.client.post(
            f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers()
        )
        assert response.status_code == 200, response.text

    response = ctx.client.post(
        f"/v1/ecourts/cases/{CASE_ID}/refresh", headers=_headers()
    )
    assert response.status_code == 429, response.text
    assert "Retry-After" in response.headers
    assert "Global refresh capacity reached" in response.json()["detail"]


def test_heartbeat_malformed_session_id_is_400(ctx):
    response = ctx.client.post(
        "/v1/presence/heartbeat?session_id=bad%2Fid", headers=_headers()
    )
    assert response.status_code == 400, response.text
    assert response.status_code != 500


def test_heartbeat_slash_session_id_is_400(ctx):
    response = ctx.client.post(
        "/v1/presence/heartbeat?session_id=a/b", headers=_headers()
    )
    assert response.status_code == 400, response.text


def test_heartbeat_empty_session_id_is_400(ctx):
    response = ctx.client.post(
        "/v1/presence/heartbeat?session_id=", headers=_headers()
    )
    assert response.status_code == 400, response.text


def test_presence_session_registration_succeeds(ctx):
    response = ctx.client.post("/v1/presence/session", headers=_headers())
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["sessionId"]
    assert body["ttlSeconds"] == 300


def test_presence_heartbeat_requires_authentication(ctx):
    response = ctx.client.post("/v1/presence/heartbeat?session_id=abc")
    assert response.status_code == 401


def test_presence_heartbeat_unknown_session_is_403(ctx):
    response = ctx.client.post(
        "/v1/presence/heartbeat?session_id=does-not-exist", headers=_headers()
    )
    assert response.status_code == 403, response.text
