"""Atomic team Case Token pool billing.

A member allocation is a per-period spending ceiling, not a separate wallet.
Every team debit updates the shared team wallet and the member's used amount
inside the same Firestore transaction. Client-supplied balances are ignored.
"""
from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Callable


class InsufficientTeamPool(Exception):
    def __init__(self, required: float, available: float) -> None:
        super().__init__("The shared team Case Token pool is insufficient.")
        self.required = required
        self.available = available


class InsufficientTeamAllocation(Exception):
    def __init__(self, required: float, available: float) -> None:
        super().__init__("The member's Case Token allocation is insufficient.")
        self.required = required
        self.available = available


class TeamBillingConflict(Exception):
    pass


@dataclass(frozen=True)
class TeamBillingResult:
    balance_after: float
    member_available_after: float
    duplicate: bool = False


def _minor_units(data: dict[str, Any]) -> int:
    if "balanceMinorUnits" in data:
        value = data.get("balanceMinorUnits")
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            raise RuntimeError("Stored team Case Token balance is invalid.")
        return value
    legacy = data.get("balance", 0)
    if isinstance(legacy, bool) or not isinstance(legacy, int) or legacy < 0:
        raise RuntimeError("Stored legacy team Case Token balance is invalid.")
    return legacy * 100


def _transaction_id(team_id: str, reference_id: str) -> str:
    return hashlib.sha256(f"team-case:{team_id}:{reference_id}".encode("utf-8")).hexdigest()


def _run_transaction(db: Any, work: Callable[[Any], Any]):
    if hasattr(db, "run_transaction"):
        result: dict[str, Any] = {}
        db.run_transaction(lambda txn: result.setdefault("value", work(txn)))
        return result.get("value")
    from google.cloud import firestore

    transaction = db.transaction(max_attempts=5)

    @firestore.transactional
    def execute(txn):
        return work(txn)

    return execute(transaction)


def _pool_ref(db: Any, team_id: str):
    return db.collection("_server_team_token_accounts").document(team_id).collection("balances").document("case")


def _ledger_ref(db: Any, team_id: str, reference_id: str):
    return (
        db.collection("_server_team_token_accounts").document(team_id)
        .collection("ledger").document(_transaction_id(team_id, reference_id))
    )


def consume_team_case_tokens(
    db: Any,
    user_id: str,
    team_id: str,
    *,
    amount_minor_units: int,
    reason: str,
    reference_id: str,
) -> TeamBillingResult:
    if isinstance(amount_minor_units, bool) or not isinstance(amount_minor_units, int) or amount_minor_units <= 0:
        raise ValueError("Team token debit must be a positive integer number of minor units.")
    if not user_id.strip() or not team_id.strip() or "/" in team_id or not reason.strip() or not reference_id.strip():
        raise ValueError("Team token billing requires valid user, team, reason, and reference.")
    team_ref = db.collection("teams").document(team_id)
    member_ref = team_ref.collection("members").document(user_id)
    account_ref = _pool_ref(db, team_id)
    ledger_ref = _ledger_ref(db, team_id, reference_id)
    transaction_id = _transaction_id(team_id, reference_id)
    period = datetime.now(timezone.utc).strftime("%Y-%m")

    def work(txn):
        # All reads happen before writes for Firestore transaction compatibility.
        prior_snap = txn.get(ledger_ref)
        team_snap = txn.get(team_ref)
        member_snap = txn.get(member_ref)
        account_snap = txn.get(account_ref)
        if prior_snap.exists:
            prior = prior_snap.to_dict() or {}
            if (
                prior.get("teamId") != team_id
                or prior.get("userId") != user_id
                or prior.get("tokenType") != "case"
                or prior.get("direction") != "debit"
                or prior.get("amountMinorUnits") != amount_minor_units
                or prior.get("reason") != reason
                or prior.get("referenceId") != reference_id
            ):
                raise TeamBillingConflict()
            return TeamBillingResult(
                float(prior.get("balanceAfter", 0)),
                float(prior.get("memberAvailableAfter", 0)),
                duplicate=True,
            )

        team = team_snap.to_dict() or {}
        member = member_snap.to_dict() or {}
        if not team_snap.exists or team.get("isActive") is False:
            raise PermissionError("Active team not found.")
        if (
            not member_snap.exists
            or member.get("isActive") is not True
            or member.get("identityType") != "firebase_uid"
            or member.get("userId") != user_id
        ):
            raise PermissionError("An active LED team membership is required.")

        limits = member.get("billingLimits")
        limits = limits if isinstance(limits, dict) else {}
        limit = limits.get("caseTokenLimitMinorUnits", 0)
        if isinstance(limit, bool) or not isinstance(limit, int) or limit < 0:
            raise RuntimeError("Stored member Case Token allocation is invalid.")
        usage = member.get("billingUsage")
        usage = usage if isinstance(usage, dict) else {}
        if usage.get("period") != period:
            used = 0
        else:
            used = usage.get("caseTokenUsedMinorUnits", 0)
        if isinstance(used, bool) or not isinstance(used, int) or used < 0:
            raise RuntimeError("Stored member Case Token usage is invalid.")
        member_available = max(0, limit - used)
        if member_available < amount_minor_units:
            raise InsufficientTeamAllocation(amount_minor_units / 100, member_available / 100)

        account_data = account_snap.to_dict() or {}
        available = _minor_units(account_data)
        if available < amount_minor_units:
            raise InsufficientTeamPool(amount_minor_units / 100, available / 100)

        after = available - amount_minor_units
        used_after = used + amount_minor_units
        member_after = dict(member)
        member_after["billingUsage"] = {
            **usage,
            "period": period,
            "caseTokenUsedMinorUnits": used_after,
            "jurisCreditUsedMinorUnits": (
                usage.get("jurisCreditUsedMinorUnits", 0) if usage.get("period") == period else 0
            ),
            "updatedAt": datetime.now(timezone.utc),
        }
        now = datetime.now(timezone.utc)
        account_after = dict(account_data)
        account_after.update({
            "tokenType": "case",
            "balance": after / 100,
            "balanceMinorUnits": after,
            "balanceUnit": "hundredths",
            "updatedAt": now,
        })
        txn.set(account_ref, account_after)
        txn.set(member_ref, member_after)
        txn.set(ledger_ref, {
            "transactionId": transaction_id,
            "userId": user_id,
            "actorUserId": user_id,
            "teamId": team_id,
            "tokenType": "case",
            "amount": amount_minor_units / 100,
            "amountMinorUnits": amount_minor_units,
            "direction": "debit",
            "reason": reason,
            "referenceId": reference_id,
            "createdAt": now,
            "billingPeriod": period,
            "balanceAfter": after / 100,
            "balanceAfterMinorUnits": after,
            "memberAvailableAfter": max(0, limit - used_after) / 100,
        })
        return TeamBillingResult(after / 100, max(0, limit - used_after) / 100)

    return _run_transaction(db, work)


def refund_team_case_tokens(
    db: Any,
    user_id: str,
    team_id: str,
    *,
    amount_minor_units: int,
    reason: str,
    reference_id: str,
) -> TeamBillingResult:
    """Idempotently refund a failed team-billed operation to its original pool."""
    if isinstance(amount_minor_units, bool) or not isinstance(amount_minor_units, int) or amount_minor_units <= 0:
        raise ValueError("Team token refund must be a positive integer number of minor units.")
    if not user_id.strip() or not team_id.strip() or not reason.strip() or not reference_id.strip():
        raise ValueError("Team token refund identity, reason, and reference are required.")
    account_ref = _pool_ref(db, team_id)
    member_ref = db.collection("teams").document(team_id).collection("members").document(user_id)
    refund_ref = _ledger_ref(db, team_id, reference_id)
    transaction_id = _transaction_id(team_id, reference_id)
    period = datetime.now(timezone.utc).strftime("%Y-%m")

    def work(txn):
        prior_snap = txn.get(refund_ref)
        account_snap = txn.get(account_ref)
        member_snap = txn.get(member_ref)
        if prior_snap.exists:
            prior = prior_snap.to_dict() or {}
            if (
                prior.get("userId") != user_id
                or prior.get("teamId") != team_id
                or prior.get("direction") != "credit"
                or prior.get("amountMinorUnits") != amount_minor_units
                or prior.get("reason") != reason
                or prior.get("referenceId") != reference_id
            ):
                raise TeamBillingConflict()
            return TeamBillingResult(float(prior.get("balanceAfter", 0)), float(prior.get("memberAvailableAfter", 0)), duplicate=True)
        if not account_snap.exists or not member_snap.exists:
            raise TeamBillingConflict()
        account_data = account_snap.to_dict() or {}
        member = member_snap.to_dict() or {}
        after = _minor_units(account_data) + amount_minor_units
        usage = member.get("billingUsage")
        usage = usage if isinstance(usage, dict) else {}
        limits = member.get("billingLimits")
        limits = limits if isinstance(limits, dict) else {}
        limit = limits.get("caseTokenLimitMinorUnits", 0)
        if isinstance(limit, bool) or not isinstance(limit, int) or limit < 0:
            raise RuntimeError("Stored member Case Token allocation is invalid.")
        used = usage.get("caseTokenUsedMinorUnits", 0) if usage.get("period") == period else 0
        if isinstance(used, bool) or not isinstance(used, int) or used < 0:
            raise RuntimeError("Stored member Case Token usage is invalid.")
        used_after = max(0, used - amount_minor_units)
        now = datetime.now(timezone.utc)
        account_after = dict(account_data)
        account_after.update({
            "tokenType": "case",
            "balance": after / 100,
            "balanceMinorUnits": after,
            "balanceUnit": "hundredths",
            "updatedAt": now,
        })
        member_after = dict(member)
        member_after["billingUsage"] = {
            **usage,
            "period": period,
            "caseTokenUsedMinorUnits": used_after,
            "jurisCreditUsedMinorUnits": usage.get("jurisCreditUsedMinorUnits", 0) if usage.get("period") == period else 0,
            "updatedAt": now,
        }
        txn.set(account_ref, account_after)
        txn.set(member_ref, member_after)
        txn.set(refund_ref, {
            "transactionId": transaction_id,
            "userId": user_id,
            "actorUserId": user_id,
            "teamId": team_id,
            "tokenType": "case",
            "amount": amount_minor_units / 100,
            "amountMinorUnits": amount_minor_units,
            "direction": "credit",
            "reason": reason,
            "referenceId": reference_id,
            "createdAt": now,
            "balanceAfter": after / 100,
            "balanceAfterMinorUnits": after,
            "memberAvailableAfter": max(0, limit - used_after) / 100,
        })
        return TeamBillingResult(after / 100, max(0, limit - used_after) / 100)

    return _run_transaction(db, work)
