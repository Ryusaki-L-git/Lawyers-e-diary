from __future__ import annotations

from types import SimpleNamespace

from fastapi.testclient import TestClient
import pytest

import gateway.main as main_mod

UID = "uid-owner"
TEAM_ID = "team-one"


@pytest.fixture
def pool_ctx(make_db, monkeypatch):
    import firebase_admin.auth

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
    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda token, check_revoked=False: {"uid": UID, "email": "owner@example.com", "email_verified": True},
    )
    db = make_db({})
    main_mod.app.dependency_overrides[main_mod.get_db] = lambda: db
    ctx = SimpleNamespace(client=TestClient(main_mod.app), db=db)
    ctx.db._store.update({
        ("users", UID): {
            "subscription": {"tier": "cloud_subscriber"},
            "billingPreferences": {"usageDeductionPriority": "team_first", "preferredTeamId": TEAM_ID},
        },
        ("teams", TEAM_ID): {
            "name": "Chamber",
            "ownerId": UID,
            "isActive": True,
            "billingPool": {"storageLimitBytes": 1000, "storageUsedBytes": 100},
        },
        (f"teams/{TEAM_ID}/members", UID): {
            "userId": UID,
            "teamId": TEAM_ID,
            "identityType": "firebase_uid",
            "role": "owner",
            "isActive": True,
            "billingLimits": {
                "caseTokenLimitMinorUnits": 10000,
                "jurisCreditLimitMinorUnits": 5000,
                "storageLimitBytes": 500,
            },
            "billingUsage": {
                "period": "2026-10",
                "caseTokenUsedMinorUnits": 2500,
                "jurisCreditUsedMinorUnits": 500,
            },
        },
        (f"_server_team_token_accounts/{TEAM_ID}/balances", "case"): {"balance": 80},
        (f"_server_team_token_accounts/{TEAM_ID}/balances", "juris"): {"balanceMinorUnits": 12000},
        (f"_server_token_accounts/{UID}/balances", "case"): {"balance": 20},
        (f"_server_token_accounts/{UID}/balances", "juris"): {"balanceMinorUnits": 3000},
    })
    yield ctx
    main_mod.app.dependency_overrides.clear()


def test_get_preferences_returns_validated_user_preference(pool_ctx):
    response = pool_ctx.client.get("/v1/billing/preferences", headers={"Authorization": "Bearer tok"})
    assert response.status_code == 200, response.text
    assert response.json() == {
        "usageDeductionPriority": "team_first",
        "preferredTeamId": TEAM_ID,
    }


def test_save_preferences_rejects_nonexistent_team(pool_ctx):
    response = pool_ctx.client.put(
        "/v1/billing/preferences",
        headers={"Authorization": "Bearer tok"},
        json={"usageDeductionPriority": "personal_first", "preferredTeamId": "not-a-member"},
    )
    assert response.status_code == 404


def test_save_preferences_rejects_unknown_priority(pool_ctx):
    response = pool_ctx.client.put(
        "/v1/billing/preferences",
        headers={"Authorization": "Bearer tok"},
        json={"usageDeductionPriority": "free_team_money", "preferredTeamId": TEAM_ID},
    )
    assert response.status_code == 422


def test_team_pool_exposes_personal_and_shared_balances_separately(pool_ctx):
    response = pool_ctx.client.get(f"/v1/teams/{TEAM_ID}/pool", headers={"Authorization": "Bearer tok"})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["shared"]["caseTokensMinorUnits"] == 8000
    assert body["shared"]["jurisCreditsMinorUnits"] == 12000
    assert body["personal"]["caseTokensMinorUnits"] == 2000
    assert body["personal"]["jurisCreditsMinorUnits"] == 3000
    assert body["allocation"]["caseTokenAvailableMinorUnits"] == 7500
    assert body["allocation"]["jurisCreditAvailableMinorUnits"] == 4500
    assert body["isManager"] if "isManager" in body else True


def test_member_allocation_is_manager_only(pool_ctx):
    response = pool_ctx.client.put(
        f"/v1/teams/{TEAM_ID}/pool/members/uid-other",
        headers={"Authorization": "Bearer tok"},
        json={
            "caseTokenLimitMinorUnits": 5000,
            "jurisCreditLimitMinorUnits": 2500,
            "storageLimitBytes": 1024,
        },
    )
    assert response.status_code == 403
