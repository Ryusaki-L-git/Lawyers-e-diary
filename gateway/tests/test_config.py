"""Tests for gateway/config.py — configuration validation and fail-closed behavior."""

from __future__ import annotations

import os
import pytest

from gateway.config import load_settings


@pytest.fixture
def env_base(monkeypatch):
    monkeypatch.setenv("FIREBASE_PROJECT_ID", "proj")
    monkeypatch.setenv(
        "FIREBASE_SERVICE_ACCOUNT_JSON",
        '{"type":"service_account","private_key":"x","client_email":"a@b.iam.gserviceaccount.com"}',
    )
    monkeypatch.setenv("ECOURTS_API_KEY", "test-key")
    monkeypatch.setenv("ECOURTS_BASE_URL", "https://example.com")


def test_valid_settings_load(env_base):
    settings = load_settings()
    assert settings.firebase_project_id == "proj"
    assert settings.ecourts_api_key == "test-key"
    assert settings.ecourts_base_url == "https://example.com"
    assert settings.request_timeout_seconds == 20


def test_missing_project_id_raises(env_base, monkeypatch):
    monkeypatch.delenv("FIREBASE_PROJECT_ID", raising=False)
    with pytest.raises(ValueError, match="FIREBASE_PROJECT_ID is required"):
        load_settings()


def test_missing_service_account_raises(env_base, monkeypatch):
    monkeypatch.delenv("FIREBASE_SERVICE_ACCOUNT_JSON", raising=False)
    with pytest.raises(ValueError, match="FIREBASE_SERVICE_ACCOUNT_JSON is required"):
        load_settings()


def test_missing_ecourts_api_key_raises(env_base, monkeypatch):
    monkeypatch.delenv("ECOURTS_API_KEY", raising=False)
    with pytest.raises(ValueError, match="ECOURTS_API_KEY and ECOURTS_BASE_URL are required"):
        load_settings()


def test_missing_ecourts_base_url_raises(env_base, monkeypatch):
    monkeypatch.delenv("ECOURTS_BASE_URL", raising=False)
    with pytest.raises(ValueError, match="ECOURTS_API_KEY and ECOURTS_BASE_URL are required"):
        load_settings()


def test_invalid_service_account_json_raises(env_base, monkeypatch):
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_JSON", "not-json")
    with pytest.raises(ValueError, match="FIREBASE_SERVICE_ACCOUNT_JSON must be a JSON object"):
        load_settings()


def test_service_account_missing_private_key_raises(env_base, monkeypatch):
    monkeypatch.setenv("FIREBASE_SERVICE_ACCOUNT_JSON", '{"type":"service_account"}')
    with pytest.raises(ValueError, match="FIREBASE_SERVICE_ACCOUNT_JSON must be a service account object"):
        load_settings()


def test_timeout_defaults_to_20(env_base):
    settings = load_settings()
    assert settings.request_timeout_seconds == 20


def test_timeout_custom_value(env_base, monkeypatch):
    monkeypatch.setenv("ECOURTS_REQUEST_TIMEOUT_SECONDS", "30")
    settings = load_settings()
    assert settings.request_timeout_seconds == 30


def test_timeout_invalid_defaults_to_20(env_base, monkeypatch):
    monkeypatch.setenv("ECOURTS_REQUEST_TIMEOUT_SECONDS", "not-a-number")
    settings = load_settings()
    assert settings.request_timeout_seconds == 20


def test_base_url_trailing_slash_stripped(env_base, monkeypatch):
    monkeypatch.setenv("ECOURTS_BASE_URL", "https://example.com/")
    settings = load_settings()
    assert settings.ecourts_base_url == "https://example.com"


def test_timeout_too_low_raises(env_base, monkeypatch):
    monkeypatch.setenv("ECOURTS_REQUEST_TIMEOUT_SECONDS", "0")
    with pytest.raises(ValueError, match="must be between 1 and 120"):
        load_settings()


def test_timeout_too_high_raises(env_base, monkeypatch):
    monkeypatch.setenv("ECOURTS_REQUEST_TIMEOUT_SECONDS", "121")
    with pytest.raises(ValueError, match="must be between 1 and 120"):
        load_settings()


def test_timeout_boundary_values(env_base, monkeypatch):
    monkeypatch.setenv("ECOURTS_REQUEST_TIMEOUT_SECONDS", "1")
    settings = load_settings()
    assert settings.request_timeout_seconds == 1

    monkeypatch.setenv("ECOURTS_REQUEST_TIMEOUT_SECONDS", "120")
    settings = load_settings()
    assert settings.request_timeout_seconds == 120
