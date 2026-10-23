"""Authentication for the LED eCourts gateway.

Verifies Firebase ID tokens presented by LED clients (Android, Windows, Web).
The gateway never issues tokens; it only attests that a bearer token is a
valid, unexpired Firebase ID token for the configured project and extracts
the trusted uid. Client-supplied uids are never trusted.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass

from fastapi import HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

logger = logging.getLogger("ecourts_gateway")

security = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class LedUser:
    """A user authenticated via a Firebase ID token."""

    uid: str
    email: str | None = None
    email_verified: bool = False


async def current_led_user(
    credentials: HTTPAuthorizationCredentials | None = Security(security),
) -> LedUser:
    """Verify the bearer Firebase ID token and return the authenticated user.

    Raises 401 for missing, malformed, expired, or revoked tokens. The uid
    returned here is the only identity the gateway trusts.
    """
    if credentials is None or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Imported inside the function so tests can patch firebase_admin.auth.
    from firebase_admin import auth as firebase_auth

    try:
        decoded = firebase_auth.verify_id_token(
            credentials.credentials, check_revoked=True
        )
    except Exception as exc:  # noqa: BLE001 - any token failure is 401
        logger.warning("LED ID token verification failed: %r", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid LED session token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    uid = decoded.get("uid")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing user id",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return LedUser(
        uid=str(uid),
        email=decoded.get("email"),
        email_verified=bool(decoded.get("email_verified", False)),
    )
