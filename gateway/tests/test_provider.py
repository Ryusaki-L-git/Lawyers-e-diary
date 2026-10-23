"""Tests for gateway/provider.py — eCourts provider client and response mapping."""

from __future__ import annotations

from types import SimpleNamespace

import httpx
import pytest

from gateway.provider import EcourtsProvider, EcourtsProviderError

CNR = "ABCD1234EFGH5678"


class FakeResponse:
    def __init__(self, status_code: int, json_data=None):
        self.status_code = status_code
        self._json = json_data

    def json(self):
        if self._json is None:
            raise ValueError("no json")
        return dict(self._json)


@pytest.fixture
def client(monkeypatch):
    """Intercept httpx.Client used by gateway.provider.

    Returns (controller, instances). Use controller.response = FakeResponse(...)
    to program the returned response; instances[0] is the last client created.
    """
    instances = []
    state = {
        "response": FakeResponse(
            200,
            {
                "data": {
                    "cnr_number": CNR,
                    "case_no": "C-1",
                    "status": "active",
                },
                "meta": {"retrieved_at": "2026-01-01T00:00:00+00:00"},
            },
        )
    }

    class FakeClient:
        def __init__(self, timeout=None, follow_redirects=False):
            instances.append(self)

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def post(self, url, headers, json=None):
            self.last_request = (url, headers, json)
            return state["response"]

    class Controller:
        @property
        def response(self):
            return state["response"]

        @response.setter
        def response(self, value):
            state["response"] = value

    fake_mod = SimpleNamespace(
        Client=FakeClient,
        TimeoutException=httpx.TimeoutException,
        RequestError=httpx.RequestError,
    )
    monkeypatch.setattr("gateway.provider.httpx", fake_mod)
    return Controller(), instances


def test_provider_post_uses_documented_endpoint(client):
    controller, instances = client
    controller.response = FakeResponse(
        200,
        {
            "data": {
                "cnr_number": CNR,
                "case_no": "C-1",
                "status": "active",
            },
            "meta": {},
        },
    )
    provider = EcourtsProvider(api_token="tok", base_url="https://example.com")
    data = provider.refresh(CNR)
    assert len(instances) == 1
    url, headers, body = instances[0].last_request
    assert url == f"https://example.com/api/partner/case/{CNR}/refresh"
    assert headers["Authorization"] == "Bearer tok"
    assert headers["Accept"] == "application/json"
    assert headers["Content-Type"] == "application/json"
    assert body == {}


def test_provider_200_maps_fields(client):
    controller, instances = client
    controller.response = FakeResponse(
        200,
        {
            "data": {
                "cnr_number": CNR,
                "case_no": "C-1",
                "case_type": "Civil",
                "status": "active",
                "court_name": "District Court",
                "petitioner": ["A"],
                "respondent": ["B"],
                "orders": [{"date": "2026-01-01", "detail": "hearing"}],
                "case_acts": ["Act X"],
            },
            "meta": {"retrieved_at": "2026-01-01T00:00:00+00:00"},
        },
    )
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    data = provider.refresh(CNR)
    assert data["cnr"] == CNR
    assert data["case_number"] == "C-1"
    assert data["case_type"] == "Civil"
    assert data["status"] == "active"
    assert data["court_name"] == "District Court"
    assert data["petitioner_names"] == ["A"]
    assert data["respondent_names"] == ["B"]
    assert data["orders"] == [{"date": "2026-01-01", "detail": "hearing"}]
    assert data["acts"] == ["Act X"]
    assert data["provider"] == "ecourtsindia"
    assert "retrieved_at" in data


def test_provider_handles_meta_envelope(client):
    """Response with top-level data + meta envelope should be handled."""
    controller, _ = client
    controller.response = FakeResponse(
        200,
        {
            "data": {"cnr_number": CNR, "case_no": "C-1", "status": "active"},
            "meta": {"retrieved_at": "2026-01-01T00:00:00+00:00", "credits_remaining": 10},
        },
    )
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    data = provider.refresh(CNR)
    assert data["cnr"] == CNR
    assert data["case_number"] == "C-1"


def test_provider_handles_no_envelope(client):
    """Response without envelope (data at top level) should still work."""
    controller, _ = client
    controller.response = FakeResponse(
        200,
        {"cnr_number": CNR, "case_no": "C-1", "status": "active"},
    )
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    data = provider.refresh(CNR)
    assert data["cnr"] == CNR


def test_provider_404_is_not_found(client):
    controller, _ = client
    controller.response = FakeResponse(404)
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 404


def test_provider_401_is_credential_reject(client):
    controller, _ = client
    controller.response = FakeResponse(401)
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 403


def test_provider_403_is_credential_reject(client):
    controller, _ = client
    controller.response = FakeResponse(403)
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 403


def test_provider_429_is_rate_limit(client):
    controller, _ = client
    controller.response = FakeResponse(429)
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 429


def test_provider_500_is_unavailable(client):
    controller, _ = client
    controller.response = FakeResponse(500)
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 502


def test_provider_503_is_unavailable(client):
    controller, _ = client
    controller.response = FakeResponse(503, {"error": "service unavailable"})
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 502


def test_provider_malformed_json_is_502(client):
    controller, _ = client
    controller.response = FakeResponse(200, None)
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 502


def test_provider_cnr_mismatch_is_502(client):
    controller, _ = client
    controller.response = FakeResponse(
        200, {"data": {"cnr_number": "OTHER1234567890", "case_no": "C-1"}}
    )
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 502


def test_provider_timeout_is_504(monkeypatch):
    def boom(*args, **kwargs):
        raise httpx.TimeoutException("t")

    monkeypatch.setattr("gateway.provider.httpx.Client", boom)
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 504


def test_provider_unreachable_is_502(monkeypatch):
    def boom(*args, **kwargs):
        raise httpx.RequestError("unreachable", request=None)

    monkeypatch.setattr("gateway.provider.httpx.Client", boom)
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 502


def test_provider_unknown_payload_shape_is_502(client):
    controller, _ = client
    controller.response = FakeResponse(200, {"not_data": {}})
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 502


def test_provider_data_not_dict_is_502(client):
    controller, _ = client
    controller.response = FakeResponse(200, {"data": "not-a-dict"})
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 502


def test_provider_no_known_fields_is_502(client):
    controller, _ = client
    controller.response = FakeResponse(200, {"data": {"unknown_field": "value"}})
    provider = EcourtsProvider(api_token="k", base_url="https://example.com")
    with pytest.raises(EcourtsProviderError) as exc:
        provider.refresh(CNR)
    assert exc.value.status_code == 502
