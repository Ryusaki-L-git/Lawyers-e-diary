"""Secure Razorpay checkout for LED's shared JURIS Credits and Case Tokens.

All prices and grants are server-owned. This module is disabled unless
PAYMENTS_ENABLED=true and Razorpay secrets are configured. It never trusts
client-supplied prices or grants balances from a client callback alone.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Any

import httpx
from fastapi import APIRouter, Depends, Header, HTTPException, Request, status

if __package__:
    from .auth import LedUser, current_led_user
    from .config import load_settings
else:
    from auth import LedUser, current_led_user
    from config import load_settings

logger = logging.getLogger("led_payments")
router = APIRouter(prefix="/v1/payments", tags=["payments"])

# Face value is ₹1 per JURIS Credit or Case Token. Pack IDs, amounts, and
# grants are deliberately server-owned; clients can select only a known pack.
PACKS: dict[str, dict[str, Any]] = {
    "juris_credits_100": {"token_type": "juris", "units": 100, "amount_paise": 10000, "label": "100 JURIS Credits"},
    "juris_credits_250": {"token_type": "juris", "units": 250, "amount_paise": 25000, "label": "250 JURIS Credits"},
    "juris_credits_500": {"token_type": "juris", "units": 500, "amount_paise": 50000, "label": "500 JURIS Credits"},
    "juris_credits_1000": {"token_type": "juris", "units": 1000, "amount_paise": 100000, "label": "1,000 JURIS Credits"},
    "case_tokens_100": {"token_type": "case", "units": 100, "amount_paise": 10000, "label": "100 Case Tokens"},
    "case_tokens_250": {"token_type": "case", "units": 250, "amount_paise": 25000, "label": "250 Case Tokens"},
    "case_tokens_500": {"token_type": "case", "units": 500, "amount_paise": 50000, "label": "500 Case Tokens"},
    "case_tokens_1000": {"token_type": "case", "units": 1000, "amount_paise": 100000, "label": "1,000 Case Tokens"},
}


def _payments_enabled() -> bool:
    return os.environ.get("PAYMENTS_ENABLED", "").strip().lower() in {"true", "1", "yes"}


def _credentials(*, webhook: bool = False) -> tuple[str, str]:
    key_id = os.environ.get("RAZORPAY_KEY_ID", "").strip()
    key_secret = os.environ.get("RAZORPAY_KEY_SECRET", "").strip()
    webhook_secret = os.environ.get("RAZORPAY_WEBHOOK_SECRET", "").strip()
    if not _payments_enabled() or not key_id or not key_secret or (webhook and not webhook_secret):
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="LED payments are not configured yet.")
    return (key_id, webhook_secret if webhook else key_secret)


def _get_db():
    """Return the same Firebase project used by the LED gateway."""
    import firebase_admin
    from firebase_admin import credentials, firestore

    settings_obj = load_settings()
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.Certificate(settings_obj.firebase_service_account),
            options={"projectId": settings_obj.firebase_project_id},
        )
    return firestore.client()


def _verify_order_signature(order_id: str, payment_id: str, signature: str, secret: str) -> bool:
    message = f"{order_id}|{payment_id}".encode("utf-8")
    expected = hmac.new(secret.encode("utf-8"), message, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def _verify_webhook_signature(raw_body: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def _minor_units(account: dict[str, Any]) -> int:
    if "balanceMinorUnits" in account:
        value = account.get("balanceMinorUnits")
        if isinstance(value, bool) or not isinstance(value, int) or value < 0:
            raise RuntimeError("Stored payment balance is invalid.")
        return value
    legacy = account.get("balance", 0)
    if isinstance(legacy, bool) or not isinstance(legacy, int) or legacy < 0:
        raise RuntimeError("Stored legacy payment balance is invalid.")
    return legacy * 100


def _transaction(db, work):
    if hasattr(db, "run_transaction"):
        result: dict[str, Any] = {}
        def capture(txn):
            result["value"] = work(txn)
        db.run_transaction(capture)
        return result.get("value")
    from google.cloud import firestore

    txn = db.transaction(max_attempts=5)

    @firestore.transactional
    def execute(transaction):
        return work(transaction)

    return execute(txn)


def _grant_captured_order(db, order_id: str, payment: dict[str, Any]) -> dict[str, Any]:
    """Atomically credit the matching account once, after server verification."""
    if not isinstance(order_id, str) or not order_id.startswith("order_"):
        raise HTTPException(status_code=400, detail="Invalid payment order.")
    if not isinstance(payment, dict):
        raise HTTPException(status_code=400, detail="Invalid payment confirmation.")

    order_ref = db.collection("_server_payment_orders").document(order_id)
    order_snapshot = order_ref.get()
    if not order_snapshot.exists:
        raise HTTPException(status_code=404, detail="Payment order was not found.")
    order = order_snapshot.to_dict() or {}
    user_id = order.get("userId")
    token_type = order.get("tokenType")
    units = order.get("grantUnits")
    amount_paise = order.get("amountPaise")
    payment_id = payment.get("id")
    if (
        not isinstance(user_id, str) or not user_id
        or token_type not in {"juris", "case"}
        or isinstance(units, bool) or not isinstance(units, int) or units <= 0
        or isinstance(amount_paise, bool) or not isinstance(amount_paise, int) or amount_paise <= 0
        or not isinstance(payment_id, str) or not payment_id.startswith("pay_")
        or payment.get("order_id") != order_id
        or payment.get("status") != "captured"
        or payment.get("currency") != "INR"
        or payment.get("amount") != amount_paise
    ):
        raise HTTPException(status_code=409, detail="Payment details do not match this order.")

    account_ref = (
        db.collection("_server_token_accounts").document(user_id)
        .collection("balances").document(token_type)
    )
    digest = hashlib.sha256(f"{token_type}:razorpay-purchase:{order_id}".encode("utf-8")).hexdigest()
    ledger_ref = (
        db.collection("_server_token_accounts").document(user_id)
        .collection("ledger").document(digest)
    )

    def work(txn):
        order_snapshot_txn = txn.get(order_ref)
        account_snapshot = txn.get(account_ref)
        ledger_snapshot = txn.get(ledger_ref)
        current_order = order_snapshot_txn.to_dict() or {}
        if current_order.get("userId") != user_id or current_order.get("amountPaise") != amount_paise:
            raise HTTPException(status_code=409, detail="Payment order ownership mismatch.")
        if ledger_snapshot.exists:
            prior = ledger_snapshot.to_dict() or {}
            if prior.get("referenceId") != f"razorpay-purchase:{order_id}" or prior.get("amountMinorUnits") != units * 100:
                raise HTTPException(status_code=409, detail="Payment ledger conflict.")
            return {"status": "paid", "duplicate": True, "tokenType": token_type, "creditedUnits": units}
        if current_order.get("state") == "paid":
            raise HTTPException(status_code=409, detail="Paid order is missing its ledger record.")

        account_data = account_snapshot.to_dict() or {}
        before = _minor_units(account_data)
        after = before + units * 100
        now = datetime.now(timezone.utc)
        txn.set(account_ref, {
            "tokenType": token_type,
            "balance": after / 100,
            "balanceMinorUnits": after,
            "balanceUnit": "hundredths",
            "updatedAt": now,
        }, merge=True)
        txn.set(ledger_ref, {
            "transactionId": digest,
            "userId": user_id,
            "actorUserId": user_id,
            "tokenType": token_type,
            "amount": float(units),
            "amountMinorUnits": units * 100,
            "direction": "credit",
            "reason": "Razorpay top-up",
            "referenceId": f"razorpay-purchase:{order_id}",
            "createdAt": now,
            "balanceAfter": after / 100,
            "balanceAfterMinorUnits": after,
            "paymentProvider": "razorpay",
            "paymentId": payment_id,
        })
        txn.set(order_ref, {
            "state": "paid",
            "paymentId": payment_id,
            "paidAt": now,
            "updatedAt": now,
        }, merge=True)
        return {"status": "paid", "duplicate": False, "tokenType": token_type, "creditedUnits": units}

    return _transaction(db, work)


@router.get("/packs")
async def list_payment_packs():
    """Return published pack denominations without exposing provider secrets."""
    return {
        "currency": "INR",
        "creditValueInRupees": 1,
        "packs": [
            {"id": pack_id, "label": value["label"], "amountPaise": value["amount_paise"],
             "tokenType": value["token_type"], "grantUnits": value["units"]}
            for pack_id, value in PACKS.items()
        ],
    }


@router.post("/orders")
async def create_payment_order(
    body: dict,
    user: LedUser = Depends(current_led_user),
    db=Depends(_get_db),
):
    """Create a Razorpay order using a server-owned pack; never accept client prices."""
    key_id, key_secret = _credentials()
    pack_id = body.get("packId")
    pack = PACKS.get(pack_id) if isinstance(pack_id, str) else None
    if pack is None:
        raise HTTPException(status_code=422, detail="Choose a valid LED top-up pack.")
    payload = {
        "amount": pack["amount_paise"],
        "currency": "INR",
        "receipt": f"led-{uuid.uuid4().hex[:24]}",
        "notes": {
            "led_user_id": user.uid,
            "led_token_type": pack["token_type"],
            "led_pack_id": pack_id,
        },
    }
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                "https://api.razorpay.com/v1/orders",
                auth=(key_id, key_secret),
                json=payload,
            )
            response.raise_for_status()
            provider_order = response.json()
    except (httpx.HTTPError, ValueError):
        logger.exception("Razorpay order creation failed")
        raise HTTPException(status_code=502, detail="The payment provider could not create an order.")

    order_id = provider_order.get("id")
    if (
        not isinstance(order_id, str) or not order_id.startswith("order_")
        or provider_order.get("amount") != pack["amount_paise"]
        or provider_order.get("currency") != "INR"
    ):
        raise HTTPException(status_code=502, detail="The payment provider returned an invalid order.")

    now = datetime.now(timezone.utc)
    db.collection("_server_payment_orders").document(order_id).set({
        "orderId": order_id,
        "userId": user.uid,
        "tokenType": pack["token_type"],
        "packId": pack_id,
        "grantUnits": pack["units"],
        "amountPaise": pack["amount_paise"],
        "currency": "INR",
        "state": "created",
        "provider": "razorpay",
        "createdAt": now,
        "updatedAt": now,
    })
    return {
        "keyId": key_id,
        "orderId": order_id,
        "amount": pack["amount_paise"],
        "currency": "INR",
        "packId": pack_id,
        "description": pack["label"],
    }


@router.post("/verify")
async def verify_payment(
    body: dict,
    user: LedUser = Depends(current_led_user),
    db=Depends(_get_db),
):
    """Verify checkout signature and captured status server-side before crediting."""
    key_id, key_secret = _credentials()
    order_id = body.get("orderId")
    payment_id = body.get("paymentId")
    signature = body.get("signature")
    if not all(isinstance(v, str) and v for v in (order_id, payment_id, signature)):
        raise HTTPException(status_code=422, detail="Payment verification fields are required.")
    order_snapshot = db.collection("_server_payment_orders").document(order_id).get()
    if not order_snapshot.exists or (order_snapshot.to_dict() or {}).get("userId") != user.uid:
        raise HTTPException(status_code=403, detail="This payment order does not belong to your account.")
    if not _verify_order_signature(order_id, payment_id, signature, key_secret):
        raise HTTPException(status_code=400, detail="Payment signature verification failed.")

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                f"https://api.razorpay.com/v1/payments/{payment_id}",
                auth=(key_id, key_secret),
            )
            response.raise_for_status()
            payment = response.json()
    except (httpx.HTTPError, ValueError):
        logger.exception("Razorpay payment lookup failed")
        raise HTTPException(status_code=502, detail="Payment status could not be verified yet.")

    if payment.get("status") != "captured":
        return {"status": "pending", "message": "Payment is not captured yet. Your balance has not been changed."}
    return _grant_captured_order(db, order_id, payment)


@router.post("/webhook")
async def razorpay_webhook(request: Request, x_razorpay_signature: str = Header(default="")):
    """Process signed captured-payment webhooks; duplicate delivery is safe."""
    _, webhook_secret = _credentials(webhook=True)
    raw_body = await request.body()
    if not x_razorpay_signature or not _verify_webhook_signature(raw_body, x_razorpay_signature, webhook_secret):
        raise HTTPException(status_code=400, detail="Invalid payment webhook signature.")
    try:
        event = json.loads(raw_body)
    except (TypeError, json.JSONDecodeError):
        raise HTTPException(status_code=400, detail="Invalid webhook payload.")
    if event.get("event") != "payment.captured":
        return {"status": "ignored"}
    payment = ((event.get("payload") or {}).get("payment") or {}).get("entity")
    if not isinstance(payment, dict) or not isinstance(payment.get("order_id"), str):
        raise HTTPException(status_code=400, detail="Captured-payment webhook is incomplete.")
    return _grant_captured_order(_get_db(), payment["order_id"], payment)
