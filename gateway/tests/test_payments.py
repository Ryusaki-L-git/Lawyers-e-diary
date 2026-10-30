from __future__ import annotations

import hashlib
import hmac

from gateway.payments import PACKS, _verify_order_signature, _verify_webhook_signature


def test_payment_packs_are_server_owned_and_match_one_rupee_per_unit():
    assert len(PACKS) == 8
    for pack_id, pack in PACKS.items():
        assert pack["amount_paise"] == pack["units"] * 100
        assert pack["token_type"] in {"juris", "case"}
        if pack["token_type"] == "juris":
            assert pack_id.startswith("juris_credits_")
        else:
            assert pack_id.startswith("case_tokens_")


def test_order_signature_verification_accepts_only_exact_hmac():
    secret = "test-secret"
    order_id = "order_123"
    payment_id = "pay_456"
    signature = hmac.new(secret.encode(), f"{order_id}|{payment_id}".encode(), hashlib.sha256).hexdigest()
    assert _verify_order_signature(order_id, payment_id, signature, secret)
    assert not _verify_order_signature(order_id, "pay_other", signature, secret)


def test_webhook_signature_verification_accepts_only_exact_body():
    secret = "webhook-secret"
    body = b'{"event":"payment.captured"}'
    signature = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    assert _verify_webhook_signature(body, signature, secret)
    assert not _verify_webhook_signature(body + b" ", signature, secret)
