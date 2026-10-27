from __future__ import annotations

import pytest

from gateway.team_pool_billing import (
    BillingSourceChoiceRequired,
    InsufficientTeamAllocation,
    InsufficientTeamPool,
    TeamBillingConflict,
    consume_case_tokens_with_preference,
    consume_team_case_tokens,
    refund_team_case_tokens,
)

UID = "uid-member"
TEAM = "team-alpha"
TEAM_BALANCE_PATH = f"_server_team_token_accounts/{TEAM}/balances"
MEMBER_PATH = f"teams/{TEAM}/members"


def _seed():
    return {
        ("teams", TEAM): {"name": "Chamber", "ownerId": "uid-owner", "isActive": True},
        (MEMBER_PATH, UID): {
            "userId": UID,
            "teamId": TEAM,
            "identityType": "firebase_uid",
            "role": "member",
            "isActive": True,
            "billingLimits": {"caseTokenLimitMinorUnits": 1000},
            "billingUsage": {"period": "2026-10", "caseTokenUsedMinorUnits": 100},
        },
        (TEAM_BALANCE_PATH, "case"): {"balance": 10},
    }


def test_team_debit_updates_shared_pool_and_member_allocation_atomically(make_db):
    db = make_db(_seed())
    result = consume_team_case_tokens(
        db, UID, TEAM, amount_minor_units=50,
        reason="Smart Refresh", reference_id="team-refresh-1",
    )
    account = db._store[(TEAM_BALANCE_PATH, "case")]
    member = db._store[(MEMBER_PATH, UID)]
    assert result.balance_after == 9.5
    assert result.member_available_after == 8.5
    assert account["balanceMinorUnits"] == 950
    assert member["billingUsage"]["caseTokenUsedMinorUnits"] == 150


def test_team_debit_is_idempotent_and_conflicting_reuse_is_rejected(make_db):
    db = make_db(_seed())
    first = consume_team_case_tokens(
        db, UID, TEAM, amount_minor_units=50,
        reason="Smart Refresh", reference_id="team-refresh-2",
    )
    duplicate = consume_team_case_tokens(
        db, UID, TEAM, amount_minor_units=50,
        reason="Smart Refresh", reference_id="team-refresh-2",
    )
    assert first.balance_after == duplicate.balance_after == 9.5
    assert duplicate.duplicate is True
    with pytest.raises(TeamBillingConflict):
        consume_team_case_tokens(
            db, UID, TEAM, amount_minor_units=100,
            reason="Different operation", reference_id="team-refresh-2",
        )


def test_team_debit_rejects_member_allocation_overrun(make_db):
    data = _seed()
    data[(MEMBER_PATH, UID)]["billingLimits"]["caseTokenLimitMinorUnits"] = 120
    db = make_db(data)
    with pytest.raises(InsufficientTeamAllocation):
        consume_team_case_tokens(
            db, UID, TEAM, amount_minor_units=50,
            reason="Smart Refresh", reference_id="team-refresh-3",
        )
    assert db._store[(TEAM_BALANCE_PATH, "case")]["balance"] == 10


def test_team_debit_rejects_insufficient_shared_pool(make_db):
    data = _seed()
    data[(TEAM_BALANCE_PATH, "case")] = {"balance": 0}
    db = make_db(data)
    with pytest.raises(InsufficientTeamPool):
        consume_team_case_tokens(
            db, UID, TEAM, amount_minor_units=50,
            reason="Smart Refresh", reference_id="team-refresh-4",
        )


def test_team_refund_is_idempotent_and_restores_pool_and_usage(make_db):
    db = make_db(_seed())
    consume_team_case_tokens(
        db, UID, TEAM, amount_minor_units=50,
        reason="Smart Refresh", reference_id="team-refresh-5",
    )
    first = refund_team_case_tokens(
        db, UID, TEAM, amount_minor_units=50,
        reason="Smart Refresh refund", reference_id="team-refresh-5:refund",
    )
    duplicate = refund_team_case_tokens(
        db, UID, TEAM, amount_minor_units=50,
        reason="Smart Refresh refund", reference_id="team-refresh-5:refund",
    )
    assert first.balance_after == duplicate.balance_after == 10
    assert duplicate.duplicate is True
    assert db._store[(MEMBER_PATH, UID)]["billingUsage"]["caseTokenUsedMinorUnits"] == 100


def test_ask_preference_requires_wallet_choice_before_charge(make_db):
    data = _seed()
    data[("users", UID)] = {
        "billingPreferences": {
            "usageDeductionPriority": "ask",
            "preferredTeamId": TEAM,
        }
    }
    db = make_db(data)
    with pytest.raises(BillingSourceChoiceRequired):
        consume_case_tokens_with_preference(
            db, UID, amount_minor_units=50, reason="Smart Refresh",
            reference_id="ask-choice-1", case_team_id=TEAM,
        )
    assert db._store[(TEAM_BALANCE_PATH, "case")]["balance"] == 10


def test_explicit_team_source_debits_team_and_member_allocation(make_db):
    data = _seed()
    data[("users", UID)] = {
        "billingPreferences": {
            "usageDeductionPriority": "ask",
            "preferredTeamId": TEAM,
        }
    }
    data[(f"_server_token_accounts/{UID}/balances", "case")] = {"balance": 20}
    db = make_db(data)
    result = consume_case_tokens_with_preference(
        db, UID, amount_minor_units=50, reason="Smart Refresh",
        reference_id="team-choice-1", case_team_id=TEAM,
        requested_source="team",
    )
    assert result.source == "team"
    assert result.team_id == TEAM
    assert db._store[(TEAM_BALANCE_PATH, "case")]["balanceMinorUnits"] == 950
    assert db._store[("_server_token_accounts", UID, "balances", "case")]["balance"] == 20


def test_personal_first_falls_back_to_team_when_personal_wallet_is_empty(make_db):
    data = _seed()
    data[("users", UID)] = {
        "billingPreferences": {
            "usageDeductionPriority": "personal_first",
            "preferredTeamId": TEAM,
        }
    }
    data[("_server_token_accounts", UID, "balances", "case")] = {"balance": 0}
    db = make_db(data)
    result = consume_case_tokens_with_preference(
        db, UID, amount_minor_units=50, reason="Smart Refresh",
        reference_id="fallback-team-1", case_team_id=TEAM,
    )
    assert result.source == "team"
    assert result.team_id == TEAM
    assert db._store[(TEAM_BALANCE_PATH, "case")]["balanceMinorUnits"] == 950
    assert db._store[("_server_token_accounts", UID, "balances", "case")]["balance"] == 0
