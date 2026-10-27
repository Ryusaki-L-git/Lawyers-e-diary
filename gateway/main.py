"""LED eCourts gateway application.

Separate FastAPI app on FastAPI Cloud (free Hobby allowance), independent of
the existing JURIS app (`juris1.fastapicloud.dev`), which is never modified
and never calls eCourts.

Trust boundaries:
  LED client (Flutter Android/Windows) -> gateway:
    HTTPS + Authorization: Bearer <Firebase ID token>
    (client never sees the eCourts API key)
  gateway -> Firestore:
    Firebase Admin SDK with a service account (private secret). Bypasses
    Firestore security rules, so this app re-implements full authorization.
  gateway -> eCourts:
    ECOURTS_API_KEY (private secret) over HTTPS.

Routes:
  GET  /healthz
  POST /v1/ecourts/cases/{case_id}/refresh   (Bearer Firebase ID token)
  POST /v1/presence/session                   (Bearer Firebase ID token)
  POST /v1/presence/heartbeat                 (Bearer Firebase ID token)

Rate limiting and abuse protection:
  1. Per-user admission limit: 5 admitted refresh attempts per verified
     Firebase UID per rolling 10-minute window (Firestore-backed).
  2. Per-case admission limit: 5 admitted refresh attempts per verified
     Firebase UID per case per rolling 300-second window (Firestore-backed).
  3. Per-case concurrency lock: prevents overlapping refreshes for the
     same case (Firestore-backed, TTL-protected).
  4. Global capacity cap: estimated unique active users × capacity
     multiplier, enforced as a shared atomic counter (Firestore-backed).
     When presence count is zero, uses configured zero-user fallback
     estimate (default 5) to avoid blocking all legitimate refreshes.

  Response classification for every gate:
    - A genuine limit (per-user window, per-case window, global capacity,
      or an active case lock) is reported as HTTP 429 with a Retry-After
      header when the retry time can be determined reliably.
    - A shared-state failure (for example a Firestore outage) is reported
      as HTTP 503 when fail-closed behaviour is enabled. A shared-state
      failure is never reported as a rate-limit rejection.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.responses import JSONResponse

if __package__:
    from .admission import AdmissionStatus
    from .auth import LedUser, current_led_user
    from .case_lock import acquire_case_lock, release_case_lock
    from .config import load_settings
    from .firestore_authz import AuthorizationError, read_case_and_authorize, reauthorize_and_update, _assert_cloud_subscription
    from .presence import (
        InvalidSessionId,
        count_unique_active_users,
        heartbeat_session,
        register_session,
    )
    from .led_id import allocate_led_id
    from .token_billing import InsufficientCaseTokens, TokenBillingConflict, consume_case_tokens, refund_case_tokens
    from .provider import EcourtsProvider, EcourtsProviderError
    from .rate_limiter import (
        admit_case_request,
        admit_global_request,
        admit_user_request,
        compute_global_capacity,
    )
else:
    from admission import AdmissionStatus
    from auth import LedUser, current_led_user
    from case_lock import acquire_case_lock, release_case_lock
    from config import load_settings
    from firestore_authz import AuthorizationError, read_case_and_authorize, reauthorize_and_update, _assert_cloud_subscription
    from presence import (
        InvalidSessionId,
        count_unique_active_users,
        heartbeat_session,
        register_session,
    )
    from led_id import allocate_led_id
    from token_billing import InsufficientCaseTokens, TokenBillingConflict, consume_case_tokens, refund_case_tokens
    from provider import EcourtsProvider, EcourtsProviderError
    from rate_limiter import (
        admit_case_request,
        admit_global_request,
        admit_user_request,
        compute_global_capacity,
    )

logger = logging.getLogger("ecourts_gateway")
logging.basicConfig(level=logging.INFO)

app = FastAPI(title="LED eCourts Gateway", version="1.1.0")


def get_settings():
    return load_settings()


def get_provider(settings=Depends(get_settings)) -> EcourtsProvider:
    return EcourtsProvider(
        api_token=settings.ecourts_api_key,
        base_url=settings.ecourts_base_url,
        timeout_seconds=settings.request_timeout_seconds,
    )


def get_db():
    """Return a Firestore client, initializing Firebase Admin on first use."""
    import firebase_admin
    from firebase_admin import credentials, firestore

    settings = get_settings()
    try:
        firebase_admin.get_app()
    except ValueError:
        cred = credentials.Certificate(settings.firebase_service_account)
        firebase_admin.initialize_app(
            cred, options={"projectId": settings.firebase_project_id}
        )
    return firestore.client()


@app.get("/healthz")
async def healthz():
    return JSONResponse(
        content={"status": "ok"},
        headers={"X-Content-Type-Options": "nosniff"},
    )


@app.post("/v1/led/allocate-id")
async def allocate_led_id_endpoint(
    user: LedUser = Depends(current_led_user),
    db=Depends(get_db),
):
    """Allocate or reuse an LED ID for the authenticated user.

    The UID is derived from the verified Firebase ID token. The year is
    derived from server time. No client-supplied year or UID is trusted.
    """
    result = allocate_led_id(db, user.uid)
    return result


@app.post("/v1/presence/session")
async def register_presence_session(
    user: LedUser = Depends(current_led_user),
    db=Depends(get_db),
):
    """Register or refresh a presence session for the authenticated user.

    Called by the Flutter client when the app starts and periodically
    while running. Each device/install gets its own session document,
    but all sessions for the same UID share the same uid_hash, so
    counting unique UIDs deduplicates multi-device users.
    """
    session_id = register_session(db, user.uid, ttl_seconds=300)
    return {"sessionId": session_id, "ttlSeconds": 300}


@app.post("/v1/presence/heartbeat")
async def heartbeat_presence_session(
    session_id: str,
    user: LedUser = Depends(current_led_user),
    db=Depends(get_db),
):
    """Refresh a presence session's heartbeat and expiration.

    The session must belong to the authenticated user (verified via uid_hash).
    Returns 400 when the session identifier is malformed, and 403 when the
    session does not exist or belongs to another user.
    """
    try:
        updated = heartbeat_session(db, session_id, user.uid, ttl_seconds=300)
    except InvalidSessionId:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid session identifier.",
        )
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Session not found or ownership mismatch.",
        )
    return {"sessionId": session_id, "ttlSeconds": 300}


@app.post("/v1/services/{service_id}/execute")
async def execute_paid_service(
    service_id: str,
    body: dict,
    user: LedUser = Depends(current_led_user),
    provider: EcourtsProvider = Depends(get_provider),
    db=Depends(get_db),
):
    """Execute only explicitly implemented, priced services through the LED gateway."""
    service_id = service_id.strip().lower()
    prices = {
        "case_detail": 500,
        "cause_list_search": 900,
        "cnr_cause_list_check": 100,
        "order_download_pdf": 1100,
        "order_ai_summary": 2200,
        "order_markdown_pdf": 1500,
        "bulk_case_refresh": 50,
    }
    if service_id not in prices:
        if service_id in {
            "case_provisions", "act_section", "act_sections_batch",
            "section_equivalents", "resolve_act_name", "search_sections",
            "electoral_search", "legal_check",
        }:
            raise HTTPException(
                status_code=status.HTTP_501_NOT_IMPLEMENTED,
                detail={
                    "code": "service_not_ready",
                    "message": "This service is not enabled until its execution and billing workflow is verified.",
                },
            )
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown service.")

    try:
        _assert_cloud_subscription(db, user.uid, db.get)
    except AuthorizationError:
        raise
    except Exception:  # noqa: BLE001
        logger.exception("Service subscription check failed")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service authorization is temporarily unavailable.",
        )

    case_id = body.get("case_id")
    case_ids = body.get("case_ids")
    params = body.get("params", {})
    filename = body.get("filename")
    signed = body.get("signed", True)
    cnr = None
    cnrs = []

    def authorize_case(requested_case_id: str):
        try:
            return read_case_and_authorize(
                db, user.uid, requested_case_id,
                auth_email=user.email, email_verified=user.email_verified,
            )
        except AuthorizationError:
            raise

    if service_id in {"case_detail", "order_download_pdf", "order_ai_summary", "order_markdown_pdf"}:
        if not isinstance(case_id, str) or not case_id.strip():
            raise HTTPException(status_code=422, detail="case_id is required.")
        access = authorize_case(case_id.strip())
        cnr = access.cnr
        if service_id.startswith("order_"):
            if (
                not isinstance(filename, str)
                or not filename.endswith(".pdf")
                or len(filename) > 128
                or not filename[0].isalnum()
                or "/" in filename
                or "\\" in filename
                or ".." in filename
                or "%" in filename
            ):
                raise HTTPException(status_code=422, detail="A valid order PDF filename is required.")
        if service_id in {"order_download_pdf", "order_markdown_pdf"} and not isinstance(signed, bool):
            raise HTTPException(status_code=422, detail="signed must be a boolean.")
    elif service_id == "cnr_cause_list_check":
        if not isinstance(case_ids, list) or not 1 <= len(case_ids) <= 100:
            raise HTTPException(status_code=422, detail="Provide between 1 and 100 case_ids.")
        for requested_case_id in case_ids:
            if not isinstance(requested_case_id, str) or not requested_case_id.strip():
                raise HTTPException(status_code=422, detail="Each case_id must be a non-empty string.")
            cnrs.append(authorize_case(requested_case_id.strip()).cnr)
        cnrs = list(dict.fromkeys(cnrs))
    elif service_id == "bulk_case_refresh":
        if not isinstance(case_ids, list) or not 2 <= len(case_ids) <= 50:
            raise HTTPException(status_code=422, detail="Bulk refresh requires between 2 and 50 case_ids.")
        for requested_case_id in case_ids:
            if not isinstance(requested_case_id, str) or not requested_case_id.strip():
                raise HTTPException(status_code=422, detail="Each case_id must be a non-empty string.")
            cnrs.append(authorize_case(requested_case_id.strip()).cnr)
        cnrs = list(dict.fromkeys(cnrs))
        if not 2 <= len(cnrs) <= 50:
            raise HTTPException(status_code=422, detail="Bulk refresh requires at least two distinct cases.")
    elif service_id == "cause_list_search":
        if not isinstance(params, dict) or not params:
            raise HTTPException(status_code=422, detail="At least one cause-list filter is required.")
        allowed = {
            "q", "date", "startDate", "endDate", "judge", "advocate", "state",
            "districtCode", "limit", "offset", "courtComplexCode", "court",
            "courtNo", "bench", "litigant", "listType", "includeCourtroom",
        }
        if set(params) - allowed or any(value is None or value == "" for value in params.values()):
            raise HTTPException(status_code=422, detail="Cause-list filters are invalid.")

    operation_id = str(uuid.uuid4())
    billing_reference = f"service:{service_id}:{operation_id}"
    amount_minor_units = prices[service_id] * (
        len(cnrs) if service_id in {"cnr_cause_list_check", "bulk_case_refresh"} else 1
    )
    charged_minor_units = amount_minor_units
    try:
        consume_case_tokens(
            db,
            user.uid,
            amount_minor_units=amount_minor_units,
            reason=service_id,
            reference_id=billing_reference,
        )
    except InsufficientCaseTokens as exc:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "code": "insufficient_tokens",
                "required": exc.required,
                "available": exc.available,
            },
        )
    except Exception:  # noqa: BLE001
        logger.exception("Paid service token debit failed")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Token billing is temporarily unavailable. The service was not started.",
        )

    try:
        if service_id == "case_detail":
            result = provider.case_detail(cnr)
        elif service_id == "cause_list_search":
            result = provider.cause_list_search(params)
        elif service_id == "cnr_cause_list_check":
            result = provider.cnr_cause_list_check(cnrs)
        elif service_id == "order_download_pdf":
            result = provider.order_download_pdf(cnr, filename, signed=signed)
        elif service_id == "order_ai_summary":
            result = provider.order_ai_summary(cnr, filename)
        elif service_id == "order_markdown_pdf":
            result = provider.order_markdown_pdf(cnr, filename, signed=signed)
        else:
            result = provider.bulk_case_refresh(cnrs)

        # Provider batch APIs report invalid CNRs separately. Refund their
        # reserved customer charge instead of charging for unprocessed cases.
        if service_id == "bulk_case_refresh":
            data = result.get("data", {}) if isinstance(result, dict) else {}
            invalid = data.get("invalid", []) if isinstance(data, dict) else []
            invalid_count = len(invalid) if isinstance(invalid, list) else 0
            refund_units = min(amount_minor_units, invalid_count * prices[service_id])
            if refund_units:
                refund_case_tokens(
                    db, user.uid, amount_minor_units=refund_units,
                    reason="Bulk Case Refresh invalid-CNR adjustment",
                    reference_id=f"{billing_reference}:invalid-adjustment",
                )
                charged_minor_units -= refund_units
        return {
            "serviceId": service_id,
            "status": "ok",
            "chargedTokens": charged_minor_units / 100,
            "data": result.get("data", result) if isinstance(result, dict) else result,
        }
    except HTTPException:
        try:
            refund_case_tokens(
                db, user.uid, amount_minor_units=amount_minor_units,
                reason=f"{service_id} failed refund",
                reference_id=f"{billing_reference}:refund",
            )
        except Exception:  # noqa: BLE001
            logger.exception("Service failed and refund could not be confirmed")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Service failed and token refund could not be confirmed. Please contact support.",
            )
        raise
    except EcourtsProviderError as exc:
        try:
            refund_case_tokens(
                db, user.uid, amount_minor_units=amount_minor_units,
                reason=f"{service_id} failed refund",
                reference_id=f"{billing_reference}:refund",
            )
        except Exception:  # noqa: BLE001
            logger.exception("Provider failed and refund could not be confirmed")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Provider failed and token refund could not be confirmed. Please contact support.",
            )
        raise HTTPException(status_code=exc.status_code, detail=exc.detail)
    except Exception:  # noqa: BLE001
        try:
            refund_case_tokens(
                db, user.uid, amount_minor_units=amount_minor_units,
                reason=f"{service_id} failed refund",
                reference_id=f"{billing_reference}:refund",
            )
        except Exception:  # noqa: BLE001
            logger.exception("Unexpected service failure and refund could not be confirmed")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Service failed and token refund could not be confirmed. Please contact support.",
            )
        logger.exception("Paid service execution failed")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="The provider service could not complete this request.",
        )


@app.post("/v1/ecourts/cases/{case_id}/refresh")
async def refresh_case(
    case_id: str,
    user: LedUser = Depends(current_led_user),
    provider: EcourtsProvider = Depends(get_provider),
    db=Depends(get_db),
    settings=Depends(get_settings),
):
    # 1. Existing case authorization and subscription checks first.
    #    Unauthorized requests must not consume a user's rate-limit allowance.
    try:
        access = read_case_and_authorize(
            db, user.uid, case_id,
            auth_email=user.email, email_verified=user.email_verified,
        )
    except AuthorizationError:
        raise
    except Exception:  # noqa: BLE001
        logger.exception("Case read/authorization failed")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to authorize this case refresh.",
        )

    # The provider refresh endpoint is idempotent for 15 seconds. Reuse the
    # completed result inside that window instead of charging the same case twice.
    last_refresh_at = access.case_data.get("lastSmartRefreshAt")
    last_billing_reference = access.case_data.get("lastSmartRefreshBillingReference")
    if isinstance(last_refresh_at, datetime) and last_billing_reference:
        if last_refresh_at.tzinfo is None:
            last_refresh_at = last_refresh_at.replace(tzinfo=timezone.utc)
        age_seconds = (datetime.now(timezone.utc) - last_refresh_at).total_seconds()
        if 0 <= age_seconds < 15:
            return {
                "caseId": case_id,
                "cnr": access.cnr,
                "status": "duplicate",
                "message": "A Smart Refresh for this case completed moments ago. No additional token was charged.",
            }

    # 2. Per-user admission limit (after authorization, before provider call).
    #    Only authorized, legitimate requests consume rate-limit tokens.
    admission = admit_user_request(
        db,
        user.uid,
        settings.rate_limit_user_max_requests,
        settings.rate_limit_user_window_seconds,
        fail_closed=settings.rate_limit_fail_closed,
    )
    if admission.rejected:
        headers = {"Retry-After": str(admission.retry_after)} if admission.retry_after else {}
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Per-user refresh limit reached.",
            headers=headers,
        )
    if admission.unavailable:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Rate limit state is temporarily unavailable.",
        )

    # 3. Per-case admission limit (after authorization, before case lock).
    #    Only authorized requests for this case consume case-level allowance.
    case_admission = admit_case_request(
        db,
        user.uid,
        case_id,
        settings.rate_limit_case_max_requests,
        settings.rate_limit_case_window_seconds,
        fail_closed=settings.rate_limit_fail_closed,
    )
    if case_admission.rejected:
        headers = {"Retry-After": str(case_admission.retry_after)} if case_admission.retry_after else {}
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Per-case refresh limit reached.",
            headers=headers,
        )
    if case_admission.unavailable:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Case rate limit state is temporarily unavailable.",
        )

    # 5. Per-case concurrency lock.
    lock_token = str(uuid.uuid4())
    lock_admission = acquire_case_lock(
        db, case_id, lock_token,
        ttl_seconds=settings.rate_limit_case_lock_ttl_seconds,
    )
    if lock_admission.rejected:
        headers = {"Retry-After": str(lock_admission.retry_after)} if lock_admission.retry_after else {}
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="A refresh for this case is already in progress.",
            headers=headers,
        )
    if lock_admission.unavailable:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Case lock state is temporarily unavailable.",
        )

    try:
        # 6. Global capacity cap before the provider call.
        # Compute capacity from presence data if available. If presence
        # query returns zero active users, use the configured zero-user
        # fallback estimate. If the presence query itself fails (Firestore
        # outage), fail closed with HTTP 503.
        try:
            presence_user_count = count_unique_active_users(
                db, settings.rate_limit_presence_ttl_seconds
            )
        except Exception:  # noqa: BLE001
            logger.exception("Presence query shared-state failure")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Presence state is temporarily unavailable.",
            )
        if presence_user_count > 0:
            effective_user_count = presence_user_count
        else:
            # No active presence detected: use the configured zero-user
            # fallback estimate so refreshes remain possible for a small
            # baseline of users. If the fallback is also 0, the capacity
            # check below will fail closed with HTTP 503.
            effective_user_count = settings.rate_limit_zero_user_fallback_users
        capacity = compute_global_capacity(
            effective_user_count, settings.rate_limit_capacity_multiplier
        )
        if capacity <= 0:
            # No safe active-user estimate and no configured estimate:
            # fail closed to avoid silently bypassing global protection.
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Global refresh capacity cannot be established.",
            )

        global_admission = admit_global_request(
            db,
            capacity,
            settings.rate_limit_global_window_seconds,
            fail_closed=settings.rate_limit_fail_closed,
        )
        if global_admission.rejected:
            headers = {"Retry-After": str(global_admission.retry_after)} if global_admission.retry_after else {}
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Global refresh capacity reached.",
                headers=headers,
            )
        if global_admission.unavailable:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Global capacity state is temporarily unavailable.",
            )

        # 7. Atomically reserve 0.5 Case Token before any provider call.
        # A missing/invalid account fails closed; no refresh is performed for free.
        billing_reference = f"smart-refresh:{case_id}:{lock_token}"
        try:
            consume_case_tokens(
                db,
                user.uid,
                amount_minor_units=50,
                reason="Smart Refresh",
                reference_id=billing_reference,
            )
        except InsufficientCaseTokens as exc:
            raise HTTPException(
                status_code=status.HTTP_402_PAYMENT_REQUIRED,
                detail={
                    "code": "insufficient_tokens",
                    "required": exc.required,
                    "available": exc.available,
                },
            )
        except TokenBillingConflict:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This Smart Refresh billing reference conflicts with an existing operation.",
            )
        except Exception:  # noqa: BLE001
            logger.exception("Smart Refresh token debit failed")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Token billing is temporarily unavailable. No refresh was started.",
            )

        # 8. Provider call and persistence. Any failure triggers an idempotent refund.
        # Record the start instant explicitly; it is persisted with the billing
        # marker so duplicate requests can be recognized without another debit.
        refresh_started_at = datetime.now(timezone.utc)
        try:
            try:
                ecourts_data = provider.refresh(access.cnr)
            except EcourtsProviderError as exc:
                raise HTTPException(status_code=exc.status_code, detail=exc.detail)

            try:
                reauthorize_and_update(
                    db, user.uid, case_id, access.cnr, ecourts_data,
                    auth_email=user.email, email_verified=user.email_verified,
                    billing_reference=billing_reference,
                    refresh_started_at=refresh_started_at,
                )
            except AuthorizationError:
                raise
            except Exception as exc:  # noqa: BLE001
                logger.exception("Firestore update failed")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Unable to persist eCourts data.",
                ) from exc
        except Exception:
            try:
                refund_case_tokens(
                    db,
                    user.uid,
                    amount_minor_units=50,
                    reason="Smart Refresh refund",
                    reference_id=f"{billing_reference}:refund",
                )
            except Exception:  # noqa: BLE001
                logger.exception("Smart Refresh failed and its token refund could not be confirmed")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="Refresh failed and token refund could not be confirmed. Please contact support before retrying.",
                )
            raise
    finally:
        # 7. Release the lock in all paths (success, provider error, write error).
        release_case_lock(db, case_id, lock_token)

    return {
        "caseId": case_id,
        "cnr": access.cnr,
        "ecourts_data": ecourts_data,
        "provider": "ecourtsindia",
        "retrieved_at": ecourts_data.get("retrieved_at"),
    }
