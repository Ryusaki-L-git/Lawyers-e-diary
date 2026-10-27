"""Atomic shared case-token billing for LED Smart Refresh.

Balances are stored as integer hundredths in balanceMinorUnits. Legacy
whole-token balances are converted in memory (balance * 100) on first debit;
no background or bulk migration is required. JURIS reads the same canonical
minor-unit field. This module never trusts client-supplied balances.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Callable


class InsufficientCaseTokens(Exception):
    def __init__(self, required: float, available: float) -> None:
        super().__init__("The current Case Token balance is insufficient.")
        self.required = required
        self.available = available


class TokenBillingConflict(Exception):
    pass


@dataclass(frozen=True)
class BillingResult:
    balance_after: float
    duplicate: bool = False


def _minor_units(account_data: dict[str, Any]) -> int:
    if "balanceMinorUnits" in account_data:
        value = account_data.get("balanceMinorUnits")
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            raise RuntimeError("Stored Case Token balance is invalid.")
        return value
    legacy = account_data.get("balance", 0)
    if isinstance(legacy, bool) or not isinstance(legacy, int) or legacy < 0:
        raise RuntimeError("Stored legacy Case Token balance is invalid.")
    return legacy * 100


def _transaction_id(reference_id: str) -> str:
    return hashlib.sha256(f"case:{reference_id}".encode("utf-8")).hexdigest()


def _run_transaction(db, work: Callable[[Any], Any]):
    # The in-memory test database exposes run_transaction(work); the deployed
    # Firestore client exposes transaction() and the transactional decorator.
    if hasattr(db, "run_transaction"):
        result: dict[str, Any] = {}
        def capture(txn):
            result["value"] = work(txn)
        db.run_transaction(capture)
        return result.get("value")
    from google.cloud import firestore

    transaction = db.transaction(max_attempts=5)

    @firestore.transactional
    def execute(txn):
        return work(txn)

    return execute(transaction)


def _account_ref(db, user_id: str):
    return (
        db.collection("_server_token_accounts")
        .document(user_id)
        .collection("balances")
        .document("case")
    )


def _ledger_ref(db, user_id: str, reference_id: str):
    return (
        db.collection("_server_token_accounts")
        .document(user_id)
        .collection("ledger")
        .document(_transaction_id(reference_id))
    )


def _ledger_entry(
    *,
    transaction_id: str,
    user_id: str,
    amount_minor_units: int,
    direction: str,
    reason: str,
    reference_id: str,
    balance_after_minor_units: int,
    created_at: datetime,
) -> dict[str, Any]:
    return {
        "transactionId": transaction_id,
        "userId": user_id,
        "actorUserId": user_id,
        "tokenType": "case",
        "amount": amount_minor_units / 100,
        "amountMinorUnits": amount_minor_units,
        "direction": direction,
        "reason": reason,
        "referenceId": reference_id,
        "createdAt": created_at,
        "balanceAfter": balance_after_minor_units / 100,
        "balanceAfterMinorUnits": balance_after_minor_units,
    }


def consume_case_tokens(
    db,
    user_id: str,
    *,
    amount_minor_units: int,
    reason: str,
    reference_id: str,
) -> BillingResult:
    if isinstance(amount_minor_units, bool) or not isinstance(amount_minor_units, int) or amount_minor_units <= 0:
        raise ValueError("Token debit must be a positive integer number of minor units.")
    if not user_id.strip() or not reason.strip() or not reference_id.strip():
        raise ValueError("Token billing identity, reason, and reference are required.")

    account_ref = _account_ref(db, user_id)
    ledger_ref = _ledger_ref(db, user_id, reference_id)
    transaction_id = _transaction_id(reference_id)

    def work(txn):
        prior_snapshot = txn.get(ledger_ref)
        if prior_snapshot.exists:
            prior = prior_snapshot.to_dict() or {}
            if (
                prior.get("userId") != user_id
                or prior.get("tokenType") != "case"
                or prior.get("amountMinorUnits") != amount_minor_units
                or prior.get("direction") != "debit"
                or prior.get("reason") != reason
                or prior.get("referenceId") != reference_id
            ):
                raise TokenBillingConflict()
            return BillingResult(float(prior.get("balanceAfter", 0)), duplicate=True)

        account_snapshot = txn.get(account_ref)
        account_data = account_snapshot.to_dict() or {}
        available = _minor_units(account_data)
        if available < amount_minor_units:
            raise InsufficientCaseTokens(amount_minor_units / 100, available / 100)

        after = available - amount_minor_units
        now = datetime.now(timezone.utc)
        account = dict(account_data)
        account.update({
            "tokenType": "case",
            "balance": after / 100,
            "balanceMinorUnits": after,
            "balanceUnit": "hundredths",
            "updatedAt": now,
        })
        txn.set(account_ref, account)
        txn.set(ledger_ref, _ledger_entry(
            transaction_id=transaction_id,
            user_id=user_id,
            amount_minor_units=amount_minor_units,
            direction="debit",
            reason=reason,
            reference_id=reference_id,
            balance_after_minor_units=after,
            created_at=now,
        ))
        return BillingResult(after / 100)

    return _run_transaction(db, work)


def refund_case_tokens(
    db,
    user_id: str,
    *,
    amount_minor_units: int,
    reason: str,
    reference_id: str,
) -> BillingResult:
    """Idempotently credit a failed refresh back to the same token account."""
    if isinstance(amount_minor_units, bool) or not isinstance(amount_minor_units, int) or amount_minor_units <= 0:
        raise ValueError("Token refund must be a positive integer number of minor units.")
    if not user_id.strip() or not reason.strip() or not reference_id.strip():
        raise ValueError("Token refund identity, reason, and reference are required.")

    account_ref = _account_ref(db, user_id)
    ledger_ref = _ledger_ref(db, user_id, reference_id)
    transaction_id = _transaction_id(reference_id)

    def work(txn):
        prior_snapshot = txn.get(ledger_ref)
        if prior_snapshot.exists:
            prior = prior_snapshot.to_dict() or {}
            if (
                prior.get("userId") != user_id
                or prior.get("tokenType") != "case"
                or prior.get("amountMinorUnits") != amount_minor_units
                or prior.get("direction") != "credit"
                or prior.get("reason") != reason
                or prior.get("referenceId") != reference_id
            ):
                raise TokenBillingConflict()
            return BillingResult(float(prior.get("balanceAfter", 0)), duplicate=True)

        account_snapshot = txn.get(account_ref)
        account_data = account_snapshot.to_dict() or {}
        after = _minor_units(account_data) + amount_minor_units
        now = datetime.now(timezone.utc)
        account = dict(account_data)
        account.update({
            "tokenType": "case",
            "balance": after / 100,
            "balanceMinorUnits": after,
            "balanceUnit": "hundredths",
            "updatedAt": now,
        })
        txn.set(account_ref, account)
        txn.set(ledger_ref, _ledger_entry(
            transaction_id=transaction_id,
            user_id=user_id,
            amount_minor_units=amount_minor_units,
            direction="credit",
            reason=reason,
            reference_id=reference_id,
            balance_after_minor_units=after,
            created_at=now,
        ))
        return BillingResult(after / 100)

    return _run_transaction(db, work)
