"""Tests for gateway/auth.py — Firebase ID token verification."""

from __future__ import annotations

from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
import pytest

from gateway.auth import current_led_user


def _cred(token: str = "tok") -> HTTPAuthorizationCredentials:
    return HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)


@pytest.mark.asyncio
async def test_missing_token_is_401(monkeypatch):
    import firebase_admin.auth

    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda t, check_revoked=False: {"uid": "u", "email": "e@x.com"},
    )
    with pytest.raises(HTTPException) as exc:
        await current_led_user(None)
    assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_invalid_token_is_401(monkeypatch):
    import firebase_admin.auth

    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda t, check_revoked=False: (_ for _ in ()).throw(Exception("bad")),
    )
    with pytest.raises(HTTPException) as exc:
        await current_led_user(_cred("bad"))
    assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_token_missing_uid_is_401(monkeypatch):
    import firebase_admin.auth

    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda t, check_revoked=False: {"email": "e@x.com"},
    )
    with pytest.raises(HTTPException) as exc:
        await current_led_user(_cred("tok"))
    assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_valid_token_returns_led_user(monkeypatch):
    import firebase_admin.auth

    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda t, check_revoked=False: {"uid": "uid-123", "email": "a@b.com"},
    )
    user = await current_led_user(_cred("good"))
    assert user.uid == "uid-123"
    assert user.email == "a@b.com"
    assert user.email_verified is False


@pytest.mark.asyncio
async def test_valid_token_email_verified(monkeypatch):
    import firebase_admin.auth

    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda t, check_revoked=False: {"uid": "uid-456", "email": "b@c.com", "email_verified": True},
    )
    user = await current_led_user(_cred("verified"))
    assert user.uid == "uid-456"
    assert user.email == "b@c.com"
    assert user.email_verified is True


@pytest.mark.asyncio
async def test_revoked_token_is_401(monkeypatch):
    import firebase_admin.auth

    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda t, check_revoked=False: (_ for _ in ()).throw(
            firebase_admin.auth.RevokedIdTokenError("revoked")
        ),
    )
    with pytest.raises(HTTPException) as exc:
        await current_led_user(_cred("revoked"))
    assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_disabled_user_is_401(monkeypatch):
    import firebase_admin.auth

    monkeypatch.setattr(
        firebase_admin.auth,
        "verify_id_token",
        lambda t, check_revoked=False: (_ for _ in ()).throw(
            firebase_admin.auth.UserDisabledError("disabled")
        ),
    )
    with pytest.raises(HTTPException) as exc:
        await current_led_user(_cred("disabled"))
    assert exc.value.status_code == 401
