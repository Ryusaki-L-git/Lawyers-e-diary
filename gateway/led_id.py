"""LED User ID allocation via the FastAPI gateway.

Reuses the existing Firebase Admin SDK and FastAPI infrastructure so no
Cloud Functions (Blaze billing) are required. The year is derived from
server time, never from a client-supplied value.
"""

from __future__ import annotations

import datetime
import logging

from fastapi import HTTPException, status

logger = logging.getLogger("ecourts_gateway")


def _is_valid_counter(value) -> bool:
    """A valid counter is a non-negative integer (never bool)."""
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _trim(value) -> str:
    if not isinstance(value, str):
        return ""
    return value.strip()


def allocate_led_id(db, uid: str) -> dict:
    """Atomically allocate or reuse an LED ID for the given authenticated UID.

    Returns {"ledId": str, "created": bool}.
    Raises HTTPException on validation/ownership/counter errors.
    """
    user_ref = db.collection("users").document(uid)
    counter_ref = db.collection("metadata").document("counters")
    directory_collection = db.collection("led_id_directory")

    result = {}

    def work(txn):
        user_snap = txn.get(user_ref)
        existing = user_snap.to_dict() if user_snap.exists else None

        stored_led_id = _trim(existing.get("ledId")) if isinstance(existing, dict) else ""

        # Reuse path: preserve exact ID, no counter increment.
        if stored_led_id:
            name = _trim(existing.get("name")) if isinstance(existing, dict) else ""
            if not name:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Profile name is required before an LED ID can be assigned.",
                )
            advocate_type = _trim(existing.get("advocateType")) if isinstance(existing, dict) else ""

            directory_ref = directory_collection.document(stored_led_id)
            dir_snap = txn.get(directory_ref)
            if dir_snap.exists:
                dir_data = dir_snap.to_dict() or {}
                owner_uid = dir_data.get("uid")
                if isinstance(owner_uid, str) and owner_uid != uid:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="The LED directory entry for this ID is owned by another account.",
                    )

            txn.set(directory_ref, {
                "uid": uid,
                "ledId": stored_led_id,
                "name": name,
                "advocateType": advocate_type,
                "profileCompleted": True,
                "updatedAt": datetime.datetime.now(datetime.timezone.utc),
            }, merge=True)

            txn.set(user_ref, {
                "ledId": stored_led_id,
                "profileCompleted": True,
                "updatedAt": datetime.datetime.now(datetime.timezone.utc),
            }, merge=True)

            result.update({"ledId": stored_led_id, "created": False})
            return

        # New allocation: validate required fields BEFORE counter.
        name = _trim(existing.get("name")) if isinstance(existing, dict) else ""
        if not name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Profile name is required before an LED ID can be assigned.",
            )
        advocate_type = _trim(existing.get("advocateType")) if isinstance(existing, dict) else ""

        counter_snap = txn.get(counter_ref)
        counter_data = counter_snap.to_dict() if counter_snap.exists else None
        raw_count = 0
        if isinstance(counter_data, dict) and "userCount" in counter_data:
            raw_count = counter_data["userCount"]

        if not _is_valid_counter(raw_count):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="The LED ID counter is in an invalid state.",
            )

        # A valid counter should already be ahead of all allocated IDs.
        # Still, fail-safe against a stale/reset counter: never overwrite an
        # existing directory entry. Skip occupied IDs inside the same
        # transaction and persist the actual allocated sequence.
        next_count = raw_count + 1
        server_year = datetime.datetime.now(datetime.timezone.utc).year
        for _ in range(10000):
            padded = str(next_count).rjust(4, "0")
            led_id = f"{padded}-{server_year}"
            candidate_ref = directory_collection.document(led_id)
            candidate_snap = txn.get(candidate_ref)
            if not candidate_snap.exists:
                break

            candidate_data = candidate_snap.to_dict() or {}
            if candidate_data.get("uid") == uid:
                # Repair a partial legacy mapping without assigning a second ID.
                now = datetime.datetime.now(datetime.timezone.utc)
                txn.set(counter_ref, {
                    "userCount": max(raw_count, next_count),
                    "updatedAt": now,
                }, merge=True)
                txn.set(user_ref, {
                    "ledId": led_id,
                    "profileCompleted": True,
                    "updatedAt": now,
                }, merge=True)
                txn.set(candidate_ref, {
                    "uid": uid,
                    "ledId": led_id,
                    "name": name,
                    "advocateType": advocate_type,
                    "profileCompleted": True,
                    "updatedAt": now,
                }, merge=True)
                result.update({"ledId": led_id, "created": False})
                return

            next_count += 1
        else:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Unable to find a free LED ID; the counter needs review.",
            )

        txn.set(counter_ref, {
            "userCount": next_count,
            "updatedAt": datetime.datetime.now(datetime.timezone.utc),
        }, merge=True)

        txn.set(user_ref, {
            "ledId": led_id,
            "profileCompleted": True,
            "updatedAt": datetime.datetime.now(datetime.timezone.utc),
        }, merge=True)

        txn.set(directory_collection.document(led_id), {
            "uid": uid,
            "ledId": led_id,
            "name": name,
            "advocateType": advocate_type,
            "profileCompleted": True,
            "updatedAt": datetime.datetime.now(datetime.timezone.utc),
        }, merge=True)

        result.update({"ledId": led_id, "created": True})

    try:
        db.run_transaction(work)
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        logger.exception("LED ID allocation failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to allocate an LED ID.",
        ) from exc

    if not result:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to allocate an LED ID.",
        )
    return result
