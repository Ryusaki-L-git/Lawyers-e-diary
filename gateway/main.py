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

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.responses import JSONResponse

if __package__:
    from .admission import AdmissionStatus
    from .auth import LedUser, current_led_user
    from .case_lock import acquire_case_lock, release_case_lock
    from .config import load_settings
    from .firestore_authz import AuthorizationError, read_case_and_authorize, reauthorize_and_update
    from .presence import (
        InvalidSessionId,
        count_unique_active_users,
        heartbeat_session,
        register_session,
    )
    from .led_id import allocate_led_id
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
    from firestore_authz import AuthorizationError, read_case_and_authorize, reauthorize_and_update
    from presence import (
        InvalidSessionId,
        count_unique_active_users,
        heartbeat_session,
        register_session,
    )
    from led_id import allocate_led_id
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


@app.get("/v1/services/catalogue")
async def service_catalogue(user: LedUser = Depends(current_led_user)):
    """Return the LED-owned service catalogue without exposing provider credentials.

    Only Smart Refresh is implemented by this gateway today. Other listed
    provider services are explicitly marked unavailable until their own
    server-side operation and billing contract are implemented.
    """
    services = [
        {
            "serviceId": "case_detail",
            "displayName": "Case Detail",
            "description": "Retrieve available details for a CNR already saved in your LED docket.",
            "providerCostRupees": 1.50,
            "tokenPrice": 5.0,
            "billingUnit": "per case detail request",
            "available": False,
        },
        {
            "serviceId": "smart_refresh",
            "displayName": "Smart Refresh",
            "description": "Refresh an existing authorized docket case from the provider.",
            "providerCostRupees": 0.15,
            "tokenPrice": 0.5,
            "billingUnit": "per refresh",
            "available": False,
        },
        {
            "serviceId": "cause_list_search",
            "displayName": "Cause List Search",
            "description": "Search cause-list entries using supported provider criteria.",
            "providerCostRupees": 3.00,
            "tokenPrice": 9.0,
            "billingUnit": "per search",
            "available": False,
        },
        {
            "serviceId": "cnr_cause_list_check",
            "displayName": "CNR Cause List Check",
            "description": "Check cause-list status for a CNR.",
            "providerCostRupees": 0.30,
            "tokenPrice": 1.0,
            "billingUnit": "per CNR",
            "available": False,
        },
        {
            "serviceId": "order_download",
            "displayName": "Order Download (PDF)",
            "description": "Retrieve an available order as a PDF.",
            "providerCostRupees": 3.75,
            "tokenPrice": 11.0,
            "billingUnit": "per order PDF",
            "available": False,
        },
        {
            "serviceId": "order_markdown_pdf",
            "displayName": "Order Markdown & PDF",
            "description": "Retrieve an order in Markdown and PDF formats.",
            "providerCostRupees": 5.25,
            "tokenPrice": 15.0,
            "billingUnit": "per order",
            "available": False,
        },
        {
            "serviceId": "order_ai_summary",
            "displayName": "Order + AI Summary",
            "description": "Retrieve an order and generate its AI summary.",
            "providerCostRupees": 7.50,
            "tokenPrice": 22.0,
            "billingUnit": "per order",
            "available": False,
        },
        {
            "serviceId": "bulk_case_refresh",
            "displayName": "Bulk Case Refresh",
            "description": "Refresh multiple authorized docket cases.",
            "providerCostRupees": 0.15,
            "tokenPrice": 0.5,
            "billingUnit": "per CNR",
            "available": False,
        },
        {
            "serviceId": "legal_check",
            "displayName": "Legal Check",
            "description": "Run a legal check on an accepted case job.",
            "providerCostRupees": 99.0,
            "tokenPrice": 199.0,
            "billingUnit": "per accepted job",
            "available": False,
        },
        {
            "serviceId": "case_provisions",
            "displayName": "Case Provisions",
            "description": "Find statutory provisions associated with a case.",
            "providerCostRupees": 0.15,
            "tokenPrice": 0.5,
            "billingUnit": "per distinct section returned",
            "available": False,
        },
        {
            "serviceId": "act_section",
            "displayName": "Act Section",
            "description": "Retrieve a section from an Act.",
            "providerCostRupees": 0.15,
            "tokenPrice": 0.5,
            "billingUnit": "per section",
            "available": False,
        },
        {
            "serviceId": "act_sections_batch",
            "displayName": "Act Sections (batch)",
            "description": "Retrieve multiple Act sections in a batch.",
            "providerCostRupees": 0.15,
            "tokenPrice": 0.5,
            "billingUnit": "per distinct section returned",
            "available": False,
        },
        {
            "serviceId": "section_equivalents",
            "displayName": "Section Equivalents",
            "description": "Resolve equivalent statutory sections.",
            "providerCostRupees": 0.15,
            "tokenPrice": 0.5,
            "billingUnit": "per successful call",
            "available": False,
        },
        {
            "serviceId": "resolve_act_name",
            "displayName": "Resolve Act Name",
            "description": "Resolve an Act name to a recognized match.",
            "providerCostRupees": 0.15,
            "tokenPrice": 0.5,
            "billingUnit": "per match returned",
            "available": False,
        },
        {
            "serviceId": "search_sections",
            "displayName": "Search Sections",
            "description": "Search statutory sections.",
            "providerCostRupees": 0.15,
            "tokenPrice": 0.5,
            "billingUnit": "per call",
            "available": False,
        },
    ]
    return services


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

        # SECURITY RELEASE GATE: token billing is not yet wired to the shared,
        # server-owned JURIS ledger. Admission and abuse controls still run, but
        # never call the paid provider until atomic debit/refund and idempotency exist.
        logger.error("Smart Refresh blocked: authoritative token billing is not configured")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Smart Refresh is temporarily unavailable while secure token billing is being completed.",
        )

        # 5. Provider call (outside the transaction).
        try:
            ecourts_data = provider.refresh(access.cnr)
        except EcourtsProviderError as exc:
            raise HTTPException(status_code=exc.status_code, detail=exc.detail)

        # 6. Transaction: re-authorize, CNR race check, write ecourts data.
        try:
            reauthorize_and_update(
                db, user.uid, case_id, access.cnr, ecourts_data,
                auth_email=user.email, email_verified=user.email_verified,
            )
        except AuthorizationError:
            raise
        except Exception:  # noqa: BLE001
            logger.exception("Firestore update failed")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Unable to persist eCourts data.",
            )
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
