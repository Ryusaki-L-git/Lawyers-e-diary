"""Server-owned team pool and deduction-preference API.

Balances are never accepted from clients. Team allocations are caps, not
additional credits: a billable operation must debit both the shared team
wallet and the member's remaining allocation in one transaction.
"""
from __future__ import annotations

import calendar
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field

if __package__:
    from .auth import LedUser, current_led_user
else:
    from auth import LedUser, current_led_user

router = APIRouter(tags=["team-pools"])

_PRIORITY_VALUES = {"personal_first", "team_first", "ask"}
_POOL_TYPES = {"case", "juris"}


def _data(snapshot: Any) -> dict[str, Any]:
    if snapshot is None or not getattr(snapshot, "exists", False):
        return {}
    value = snapshot.to_dict()
    return value if isinstance(value, dict) else {}


def _int_field(value: Any, name: str, *, maximum: int = 10**15) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0 or value > maximum:
        raise HTTPException(status_code=422, detail=f"{name} must be a non-negative integer.")
    return value


def _team_and_member(db: Any, team_id: str, uid: str) -> tuple[dict[str, Any], dict[str, Any]]:
    if not team_id or "/" in team_id or team_id in {".", ".."}:
        raise HTTPException(status_code=400, detail="Invalid team identifier.")
    team_snap = db.collection("teams").document(team_id).get()
    member_snap = db.collection("teams").document(team_id).collection("members").document(uid).get()
    team = _data(team_snap)
    member = _data(member_snap)
    if not team or team.get("isActive") is False:
        raise HTTPException(status_code=404, detail="Active team not found.")
    if not member or member.get("isActive") is not True or member.get("identityType") != "firebase_uid" or member.get("userId") != uid:
        raise HTTPException(status_code=403, detail="An active LED team membership is required.")
    return team, member


def _stored_minor_units(data: dict[str, Any]) -> int:
    value = data.get("balanceMinorUnits")
    if value is not None:
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            raise HTTPException(status_code=503, detail="Stored wallet balance is invalid.")
        return value
    legacy = data.get("balance", 0)
    if isinstance(legacy, bool) or not isinstance(legacy, int) or legacy < 0:
        raise HTTPException(status_code=503, detail="Stored legacy wallet balance is invalid.")
    return legacy * 100


def _balance(db: Any, collection: str, owner_id: str, wallet_type: str) -> int:
    snap = (
        db.collection(collection).document(owner_id)
        .collection("balances").document(wallet_type).get()
    )
    return _stored_minor_units(_data(snap))


class DeductionPreferenceRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    usageDeductionPriority: str = Field(default="ask")
    preferredTeamId: str | None = Field(default=None, max_length=128)


class MemberAllocationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    caseTokenLimitMinorUnits: int = Field(ge=0, le=10**15)
    jurisCreditLimitMinorUnits: int = Field(ge=0, le=10**15)
    storageLimitBytes: int = Field(ge=0, le=10**18)


def make_router(get_db_dependency):
    """Bind routes to the gateway's existing authenticated Firestore dependency."""
    api = APIRouter(tags=["team-pools"])

    @api.get("/v1/billing/preferences")
    async def get_billing_preferences(
        user: LedUser = Depends(current_led_user),
        db=Depends(get_db_dependency),
    ):
        profile = _data(db.collection("users").document(user.uid).get())
        prefs = profile.get("billingPreferences")
        prefs = prefs if isinstance(prefs, dict) else {}
        priority = prefs.get("usageDeductionPriority", "ask")
        if priority not in _PRIORITY_VALUES:
            priority = "ask"
        team_id = prefs.get("preferredTeamId")
        if not isinstance(team_id, str) or not team_id:
            team_id = None
        if team_id is not None:
            try:
                _team_and_member(db, team_id, user.uid)
            except HTTPException:
                team_id = None
        return {"usageDeductionPriority": priority, "preferredTeamId": team_id}

    @api.put("/v1/billing/preferences")
    async def set_billing_preferences(
        body: DeductionPreferenceRequest,
        user: LedUser = Depends(current_led_user),
        db=Depends(get_db_dependency),
    ):
        if body.usageDeductionPriority not in _PRIORITY_VALUES:
            raise HTTPException(status_code=422, detail="Unsupported deduction priority.")
        team_id = body.preferredTeamId.strip() if body.preferredTeamId else None
        if team_id:
            _team_and_member(db, team_id, user.uid)
        db.collection("users").document(user.uid).set({
            "billingPreferences": {
                "usageDeductionPriority": body.usageDeductionPriority,
                "preferredTeamId": team_id,
                "updatedAt": datetime.now(timezone.utc),
            }
        }, merge=True)
        return {"usageDeductionPriority": body.usageDeductionPriority, "preferredTeamId": team_id}

    @api.get("/v1/teams/{team_id}/pool")
    async def get_team_pool(
        team_id: str,
        user: LedUser = Depends(current_led_user),
        db=Depends(get_db_dependency),
    ):
        team, member = _team_and_member(db, team_id, user.uid)
        case_minor = _balance(db, "_server_team_token_accounts", team_id, "case")
        juris_minor = _balance(db, "_server_team_token_accounts", team_id, "juris")
        personal_case_minor = _balance(db, "_server_token_accounts", user.uid, "case")
        personal_juris_minor = _balance(db, "_server_token_accounts", user.uid, "juris")
        limits = member.get("billingLimits")
        limits = limits if isinstance(limits, dict) else {}
        usage = member.get("billingUsage")
        usage = usage if isinstance(usage, dict) else {}
        period = datetime.now(timezone.utc).strftime("%Y-%m")
        if usage.get("period") != period:
            usage = {"period": period, "caseTokenUsedMinorUnits": 0, "jurisCreditUsedMinorUnits": 0}
        case_limit = limits.get("caseTokenLimitMinorUnits", 0)
        juris_limit = limits.get("jurisCreditLimitMinorUnits", 0)
        storage_limit = limits.get("storageLimitBytes", 0)
        for value in (case_limit, juris_limit, storage_limit):
            if isinstance(value, bool) or not isinstance(value, int) or value < 0:
                raise HTTPException(status_code=503, detail="Stored member allocation is invalid.")
        case_used = usage.get("caseTokenUsedMinorUnits", 0)
        juris_used = usage.get("jurisCreditUsedMinorUnits", 0)
        if not isinstance(case_used, int) or not isinstance(juris_used, int):
            raise HTTPException(status_code=503, detail="Stored member usage is invalid.")
        pool = team.get("billingPool")
        pool = pool if isinstance(pool, dict) else {}
        return {
            "teamId": team_id,
            "teamName": str(team.get("name", "Team")),
            "role": member.get("role", "member"),
            "isManager": member.get("role") in {"owner", "leader"},
            "shared": {
                "caseTokensMinorUnits": case_minor,
                "jurisCreditsMinorUnits": juris_minor,
                "storageLimitBytes": pool.get("storageLimitBytes", 0),
                "storageUsedBytes": pool.get("storageUsedBytes", 0),
            },
            "personal": {
                "caseTokensMinorUnits": personal_case_minor,
                "jurisCreditsMinorUnits": personal_juris_minor,
            },
            "allocation": {
                "caseTokenLimitMinorUnits": case_limit,
                "caseTokenUsedMinorUnits": case_used,
                "caseTokenAvailableMinorUnits": max(0, case_limit - case_used),
                "jurisCreditLimitMinorUnits": juris_limit,
                "jurisCreditUsedMinorUnits": juris_used,
                "jurisCreditAvailableMinorUnits": max(0, juris_limit - juris_used),
                "storageLimitBytes": storage_limit,
            },
            "period": period,
        }

    @api.put("/v1/teams/{team_id}/pool/members/{member_uid}")
    async def set_member_allocation(
        team_id: str,
        member_uid: str,
        body: MemberAllocationRequest,
        user: LedUser = Depends(current_led_user),
        db=Depends(get_db_dependency),
    ):
        team, actor = _team_and_member(db, team_id, user.uid)
        if team.get("ownerId") != user.uid and actor.get("role") not in {"owner", "leader"}:
            raise HTTPException(status_code=403, detail="Only the team owner or leader can manage allocations.")
        _, target = _team_and_member(db, team_id, member_uid)
        # The client can set limits only; wallet balances and usage counters are server-owned.
        db.collection("teams").document(team_id).collection("members").document(member_uid).set({
            "billingLimits": {
                "caseTokenLimitMinorUnits": body.caseTokenLimitMinorUnits,
                "jurisCreditLimitMinorUnits": body.jurisCreditLimitMinorUnits,
                "storageLimitBytes": body.storageLimitBytes,
                "updatedBy": user.uid,
                "updatedAt": datetime.now(timezone.utc),
            }
        }, merge=True)
        return {"teamId": team_id, "memberUid": member_uid, "billingLimits": {
            "caseTokenLimitMinorUnits": body.caseTokenLimitMinorUnits,
            "jurisCreditLimitMinorUnits": body.jurisCreditLimitMinorUnits,
            "storageLimitBytes": body.storageLimitBytes,
        }}

    return api
