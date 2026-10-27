"""Firestore authorization for the LED eCourts gateway.

Reimplements the server-side authorization rules from the existing
Cloud Function `refreshCaseFromECourts` so the gateway never trusts a
client-supplied uid, subscription claim, or case-authorization claim.

All reads/writes go through the Firebase Admin SDK, which bypasses
Firestore security rules; therefore this module is the *entire*
authorization boundary for case data.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable

from fastapi import HTTPException, status

logger = logging.getLogger("ecourts_gateway")

CNR_PATTERN = re.compile(r"^[A-Z0-9]{16}$")
MAX_CASE_ID_BYTES = 256


class AuthorizationError(HTTPException):
    """Raised when a request fails authorization or a precondition."""

    def __init__(self, status_code: int, detail: str):
        super().__init__(status_code=status_code, detail=detail)


@dataclass(frozen=True)
class CaseAccess:
    case_id: str
    cnr: str
    case_data: dict


def _get_snapshot_data(snapshot) -> dict:
    if snapshot is None or not getattr(snapshot, "exists", False):
        return {}
    try:
        data = snapshot.to_dict()
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def _is_record(value) -> bool:
    return value is not None and isinstance(value, dict)


def _validate_case_id(case_id: str) -> str:
    if not isinstance(case_id, str):
        raise AuthorizationError(status.HTTP_400_BAD_REQUEST, "A case identifier is required.")
    case_id = case_id.strip()
    if (
        not case_id
        or len(case_id.encode("utf-8")) > MAX_CASE_ID_BYTES
        or "/" in case_id
        or case_id in (".", "..")
        or any(ord(ch) < 0x20 or ord(ch) == 0x7F for ch in case_id)
    ):
        raise AuthorizationError(status.HTTP_400_BAD_REQUEST, "The case identifier is invalid.")
    return case_id


def _stored_cnr(case_data: dict) -> str:
    """Resolve the canonical CUID and reject conflicting stored CNR aliases."""
    raw_values = [
        case_data.get(key)
        for key in ("cuid", "cnrNumber", "cnr")
        if isinstance(case_data.get(key), str) and case_data.get(key).strip()
    ]
    if not raw_values:
        raise AuthorizationError(
            status.HTTP_409_CONFLICT,
            "This case does not have a CNR number.",
        )

    normalized = [value.strip().upper() for value in raw_values]
    if any(not CNR_PATTERN.fullmatch(value) for value in normalized):
        raise AuthorizationError(
            status.HTTP_409_CONFLICT,
            "This case does not contain a valid 16-character CNR number.",
        )
    if len(set(normalized)) != 1:
        raise AuthorizationError(
            status.HTTP_409_CONFLICT,
            "The stored CUID and CNR fields do not match.",
        )
    return normalized[0]

def _team_id_from_case(case_data: dict) -> str | None:
    team_id = case_data.get("teamId")
    team_id = team_id.strip() if isinstance(team_id, str) else ""
    if not team_id or "/" in team_id:
        return None
    return team_id


def _assigned_user_matches(case_data: dict, uid: str) -> bool:
    return case_data.get("assignedTo") == uid or case_data.get("assignedUserUid") == uid


def _member_is_active(snapshot) -> bool:
    if not snapshot.exists:
        return False
    return _get_snapshot_data(snapshot).get("isActive") is not False


def _is_authorized_case_user(
    db, uid: str, case_data: dict, get_fn: Callable,
    auth_email: str | None = None, email_verified: bool = False,
    get_members_fn: Callable | None = None,
) -> bool:
    """Return True if uid may access the case.

    `get_fn(ref)` must return a Firestore DocumentSnapshot (db.get or
    transaction.get both satisfy this). `get_members_fn`, when provided,
    returns a list of additional member snapshots matched by verified
    email (H-3).
    """
    # Direct case owner / legacy owner access.
    if case_data.get("ownerUid") == uid or case_data.get("userId") == uid:
        return True

    team_id = _team_id_from_case(case_data)
    if team_id is None:
        # Non-team assigned cases may be accessed by the assigned user.
        return _assigned_user_matches(case_data, uid)

    team_ref = db.collection("teams").document(team_id)
    team_snapshot = get_fn(team_ref)
    # H-2: Team document missing -> fall through to assigned-user check,
    # matching the existing Cloud Function behavior.
    if not team_snapshot.exists:
        return _assigned_user_matches(case_data, uid)

    team_data = _get_snapshot_data(team_snapshot)
    if team_data.get("isActive") is False:
        return False

    # Team owner always has access to team cases.
    if team_data.get("ownerId") == uid:
        return True

    # For team cases, only the actively assigned member gets access.
    if not _assigned_user_matches(case_data, uid):
        return False

    # The assigned user must still be an active team member.
    # Check the uid member doc plus any verified-email-matched members (H-3).
    member_snapshots = []
    member_ref = team_ref.collection("members").document(uid)
    member_snapshots.append(get_fn(member_ref))

    if get_members_fn is not None:
        member_snapshots.extend(get_members_fn())

    return any(_member_is_active(s) for s in member_snapshots)


def _assert_cloud_subscription(db, uid: str, get_fn: Callable) -> None:
    user_ref = db.collection("users").document(uid)
    user_snapshot = get_fn(user_ref)
    user_data = _get_snapshot_data(user_snapshot)
    subscription = user_data.get("subscription")
    if not _is_record(subscription) or subscription.get("tier") != "cloud_subscriber":
        raise AuthorizationError(
            status.HTTP_403_FORBIDDEN,
            "eCourts refresh requires a Cloud Subscriber plan.",
        )


def read_case_and_authorize(
    db, uid: str, case_id: str,
    auth_email: str | None = None, email_verified: bool = False,
) -> CaseAccess:
    """Read a case, verify subscription + ownership, and return its CNR.

    Raises AuthorizationError with the appropriate HTTP status on failure.
    """
    case_id = _validate_case_id(case_id)

    case_ref = db.collection("cases").document(case_id)
    case_snapshot = db.get(case_ref)
    if not case_snapshot.exists:
        raise AuthorizationError(status.HTTP_404_NOT_FOUND, "The requested case was not found.")
    case_data = _get_snapshot_data(case_snapshot)

    _assert_cloud_subscription(db, uid, db.get)

    team_id = _team_id_from_case(case_data)
    get_members_fn = None
    if email_verified and auth_email and team_id is not None:
        def _get_members():
            members_ref = (
                db.collection("teams").document(team_id).collection("members")
            )
            query = (
                members_ref.where("email", "==", auth_email.strip().lower())
                .where("isActive", "==", True)
            )
            return list(query.get())
        get_members_fn = _get_members

    if not _is_authorized_case_user(
        db, uid, case_data, db.get, auth_email, email_verified, get_members_fn
    ):
        raise AuthorizationError(
            status.HTTP_403_FORBIDDEN,
            "You are not authorized to access this case.",
        )

    cnr = _stored_cnr(case_data)
    return CaseAccess(case_id=case_id, cnr=cnr, case_data=case_data)


def reauthorize_and_update(
    db, uid: str, case_id: str, expected_cnr: str, ecourts_data: dict,
    auth_email: str | None = None, email_verified: bool = False,
    billing_reference: str | None = None,
    refresh_started_at: datetime | None = None,
) -> None:
    """Re-authorize and persist refreshed data with a billing idempotency marker."""
    case_ref = db.collection("cases").document(case_id)

    def _work(transaction):
        fresh_snapshot = transaction.get(case_ref)
        if not fresh_snapshot.exists:
            raise AuthorizationError(status.HTTP_404_NOT_FOUND, "The requested case was not found.")
        fresh_data = _get_snapshot_data(fresh_snapshot)

        if _stored_cnr(fresh_data) != expected_cnr:
            raise AuthorizationError(
                status.HTTP_409_CONFLICT,
                "The case CNR changed during refresh. Please try again.",
            )

        _assert_cloud_subscription(db, uid, transaction.get)

        team_id = _team_id_from_case(fresh_data)
        get_members_fn = None
        if email_verified and auth_email and team_id is not None:
            def _txn_get_members():
                members_ref = (
                    db.collection("teams").document(team_id).collection("members")
                )
                query = (
                    members_ref.where("email", "==", auth_email.strip().lower())
                    .where("isActive", "==", True)
                )
                return list(transaction.get(query))
            get_members_fn = _txn_get_members

        if not _is_authorized_case_user(
            db, uid, fresh_data, transaction.get,
            auth_email, email_verified, get_members_fn,
        ):
            raise AuthorizationError(
                status.HTTP_403_FORBIDDEN,
                "You are not authorized to access this case.",
            )

        update_data = {"ecourts_data": ecourts_data}
        if billing_reference:
            update_data.update({
                "lastSmartRefreshAt": refresh_started_at or datetime.now(timezone.utc),
                "lastSmartRefreshBillingReference": billing_reference,
            })
        transaction.update(case_ref, update_data)

    db.run_transaction(_work)
