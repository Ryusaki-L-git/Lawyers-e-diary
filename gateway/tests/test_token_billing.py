from __future__ import annotations

import pytest

from gateway.token_billing import (
    InsufficientCaseTokens,
    TokenBillingConflict,
    consume_case_tokens,
    refund_case_tokens,
)

UID = "uid-owner"
BALANCE_PATH = f"_server_token_accounts/{UID}/balances"


def test_smart_refresh_debits_half_token_and_migrates_legacy_balance(make_db):
    db = make_db({(BALANCE_PATH, "case"): {"balance": 10}})

    result = consume_case_tokens(
        db,
        UID,
        amount_minor_units=50,
        reason="Smart Refresh",
        reference_id="refresh-operation-1",
    )

    account = db._store[(BALANCE_PATH, "case")]
    assert result.balance_after == 9.5
    assert account["balanceMinorUnits"] == 950
    assert account["balance"] == 9.5
    assert account["balanceUnit"] == "hundredths"

    ledger_path = f"_server_token_accounts/{UID}/ledger"
    entry = next(value for (path, _), value in db._store.items()
                 if path == ledger_path and value.get("referenceId") == "refresh-operation-1")
    assert entry["amount"] == 0.5
    assert entry["amountMinorUnits"] == 50
    assert entry["direction"] == "debit"
    assert entry["balanceAfterMinorUnits"] == 950


def test_smart_refresh_rejects_insufficient_balance_without_debit(make_db):
    db = make_db({(BALANCE_PATH, "case"): {"balance": 0}})

    with pytest.raises(InsufficientCaseTokens) as error:
        consume_case_tokens(
            db,
            UID,
            amount_minor_units=50,
            reason="Smart Refresh",
            reference_id="refresh-operation-2",
        )

    assert error.value.required == 0.5
    assert error.value.available == 0
    assert db._store[(BALANCE_PATH, "case")]["balance"] == 0
    assert not any(
        path == f"_server_token_accounts/{UID}/ledger"
        for path, _ in db._store
    )


def test_smart_refresh_debit_is_idempotent_and_conflicts_are_rejected(make_db):
    db = make_db({(BALANCE_PATH, "case"): {"balance": 3}})

    first = consume_case_tokens(
        db, UID, amount_minor_units=50, reason="Smart Refresh",
        reference_id="refresh-operation-3",
    )
    duplicate = consume_case_tokens(
        db, UID, amount_minor_units=50, reason="Smart Refresh",
        reference_id="refresh-operation-3",
    )
    assert first.balance_after == duplicate.balance_after == 2.5
    assert duplicate.duplicate is True

    with pytest.raises(TokenBillingConflict):
        consume_case_tokens(
            db, UID, amount_minor_units=100, reason="Different operation",
            reference_id="refresh-operation-3",
        )


def test_failed_refresh_refund_restores_balance_exactly_once(make_db):
    db = make_db({(BALANCE_PATH, "case"): {"balance": 2}})

    consume_case_tokens(
        db, UID, amount_minor_units=50, reason="Smart Refresh",
        reference_id="refresh-operation-4",
    )
    first_refund = refund_case_tokens(
        db, UID, amount_minor_units=50, reason="Smart Refresh refund",
        reference_id="refresh-operation-4:refund",
    )
    duplicate_refund = refund_case_tokens(
        db, UID, amount_minor_units=50, reason="Smart Refresh refund",
        reference_id="refresh-operation-4:refund",
    )

    account = db._store[(BALANCE_PATH, "case")]
    assert first_refund.balance_after == duplicate_refund.balance_after == 2
    assert duplicate_refund.duplicate is True
    assert account["balanceMinorUnits"] == 200
