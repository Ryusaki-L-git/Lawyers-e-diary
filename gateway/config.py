"""Configuration for the LED eCourts gateway.

All values are read from environment variables / FastAPI Cloud secrets.
No credential is ever hard-coded, logged, or returned in a response.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    firebase_project_id: str
    firebase_service_account: dict
    ecourts_api_key: str
    ecourts_base_url: str
    request_timeout_seconds: int = 20
    rate_limit_user_max_requests: int = 5
    rate_limit_user_window_seconds: int = 600
    rate_limit_case_max_requests: int = 5
    rate_limit_case_window_seconds: int = 300
    rate_limit_capacity_multiplier: int = 5
    rate_limit_estimated_active_users: int = 0
    rate_limit_zero_user_fallback_users: int = 5
    rate_limit_presence_ttl_seconds: int = 300
    rate_limit_global_window_seconds: int = 3600
    rate_limit_case_lock_ttl_seconds: int = 30
    rate_limit_fail_closed: bool = True


def load_settings() -> Settings:
    """Load settings from the environment.

    Raises ValueError when a required secret is missing so the app fails
    closed instead of starting without credentials.
    """
    project_id = os.environ.get("FIREBASE_PROJECT_ID", "").strip()
    if not project_id:
        raise ValueError("FIREBASE_PROJECT_ID is required")

    sa_raw = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if not sa_raw:
        raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON is required")
    try:
        service_account = json.loads(sa_raw)
    except json.JSONDecodeError as exc:
        raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON must be a JSON object") from exc
    if not isinstance(service_account, dict) or "private_key" not in service_account:
        raise ValueError("FIREBASE_SERVICE_ACCOUNT_JSON must be a service account object")

    api_key = os.environ.get("ECOURTS_API_KEY", "").strip()
    base_url = os.environ.get("ECOURTS_BASE_URL", "").strip().rstrip("/")
    if not api_key or not base_url:
        raise ValueError("ECOURTS_API_KEY and ECOURTS_BASE_URL are required")

    try:
        timeout = int(os.environ.get("ECOURTS_REQUEST_TIMEOUT_SECONDS", "20"))
    except ValueError:
        timeout = 20
    if timeout < 1 or timeout > 120:
        raise ValueError("ECOURTS_REQUEST_TIMEOUT_SECONDS must be between 1 and 120")

    return Settings(
        firebase_project_id=project_id,
        firebase_service_account=service_account,
        ecourts_api_key=api_key,
        ecourts_base_url=base_url,
        request_timeout_seconds=timeout,
        rate_limit_user_max_requests=_parse_int_env(
            os.environ, "RATE_LIMIT_USER_MAX_REQUESTS", 5, 1, 1000
        ),
        rate_limit_user_window_seconds=_parse_int_env(
            os.environ, "RATE_LIMIT_USER_WINDOW_SECONDS", 600, 1, 86400
        ),
        rate_limit_case_max_requests=_parse_int_env(
            os.environ, "RATE_LIMIT_CASE_MAX_REQUESTS", 5, 1, 1000
        ),
        rate_limit_case_window_seconds=_parse_int_env(
            os.environ, "RATE_LIMIT_CASE_WINDOW_SECONDS", 300, 1, 86400
        ),
        rate_limit_capacity_multiplier=_parse_int_env(
            os.environ, "RATE_LIMIT_CAPACITY_MULTIPLIER", 5, 1, 100
        ),
        rate_limit_estimated_active_users=_parse_int_env(
            os.environ, "RATE_LIMIT_ESTIMATED_ACTIVE_USERS", 0, 0, 100000
        ),
        rate_limit_zero_user_fallback_users=_parse_int_env(
            os.environ, "RATE_LIMIT_ZERO_USER_FALLBACK_USERS", 5, 0, 100000
        ),
        rate_limit_presence_ttl_seconds=_parse_int_env(
            os.environ, "RATE_LIMIT_PRESENCE_TTL_SECONDS", 300, 30, 86400
        ),
        rate_limit_global_window_seconds=_parse_int_env(
            os.environ, "RATE_LIMIT_GLOBAL_WINDOW_SECONDS", 3600, 60, 86400
        ),
        rate_limit_case_lock_ttl_seconds=_parse_int_env(
            os.environ, "RATE_LIMIT_CASE_LOCK_TTL_SECONDS", 30, 5, 3600
        ),
        rate_limit_fail_closed=_parse_bool_env(
            os.environ, "RATE_LIMIT_FAIL_CLOSED", "true"
        ),
    )


def _parse_int_env(
    env: dict, key: str, default: int, min_val: int, max_val: int
) -> int:
    """Parse an integer environment variable with bounds validation."""
    raw = env.get(key, "").strip()
    if not raw:
        return default
    try:
        value = int(raw)
    except ValueError:
        return default
    if value < min_val or value > max_val:
        return default
    return value


def _parse_bool_env(env: dict, key: str, default: str) -> bool:
    """Parse a boolean environment variable."""
    raw = env.get(key, default).strip().lower()
    return raw in ("true", "1", "yes", "on")
