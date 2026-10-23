"""eCourts provider client for the LED eCourts gateway.

The gateway owns the eCourts API token and performs the provider call
server-side. Clients and JURIS never see the token.

Provider contract (per https://ecourtsindia.com/api/docs):
  Base URL: https://webapi.ecourtsindia.com
  Auth:     Authorization: Bearer <provider token>
  Refresh:  POST /api/partner/case/{cnr}/refresh
  Response envelope: { "data": {...}, "meta": {...} }

NOTE: The documented contract is NOT confirmed against the live provider.
This client implements the documented contract and is intentionally
swappable: no live provider calls are made in tests, and the base URL/token
come from secrets only.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone

import httpx

logger = logging.getLogger("ecourts_gateway")

REFRESH_PATH = "/api/partner/case/{cnr}/refresh"

KNOWN_PROVIDER_FIELDS = {
    "cnr_number",
    "cnr",
    "case_no",
    "case_number",
    "case_type",
    "filing_date",
    "registration_date",
    "case_status",
    "status",
    "stage_of_case",
    "stage",
    "court_name",
    "court_number_chamber",
    "court_number",
    "state_name",
    "state",
    "district_name",
    "district",
    "petitioner",
    "petitioners",
    "petitioner_names",
    "petitioner_advocate",
    "respondent",
    "respondents",
    "respondent_names",
    "respondent_advocate",
    "next_hearing_date",
    "last_hearing_date",
    "case_acts",
    "acts",
    "orders",
    "history",
}


class EcourtsProviderError(Exception):
    """Raised when the eCourts provider cannot be used."""

    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


@dataclass(frozen=True)
class EcourtsProvider:
    api_token: str
    base_url: str
    timeout_seconds: int = 20

    def refresh(self, cnr: str) -> dict:
        """Call the eCourts provider refresh endpoint and return a normalized case snapshot."""
        url = f"{self.base_url}{REFRESH_PATH.format(cnr=cnr)}"
        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        try:
            with httpx.Client(timeout=self.timeout_seconds, follow_redirects=False) as client:
                response = client.post(url, headers=headers, json={})
        except httpx.TimeoutException as exc:
            logger.warning("eCourts provider request timed out: %r", exc)
            raise EcourtsProviderError(504, "The eCourts provider timed out.")
        except httpx.RequestError as exc:
            logger.warning("eCourts provider could not be reached: %r", exc)
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.")

        if response.status_code == 404:
            raise EcourtsProviderError(404, "The case was not found in eCourts.")
        if response.status_code == 400:
            raise EcourtsProviderError(400, "The eCourts provider rejected this CNR.")
        if response.status_code in (401, 403):
            logger.error("eCourts provider rejected server authentication.")
            raise EcourtsProviderError(
                403, "The eCourts provider rejected its configured credentials."
            )
        if response.status_code == 429:
            raise EcourtsProviderError(429, "The eCourts provider rate limit was reached.")
        if response.status_code >= 500:
            logger.warning("eCourts provider returned a server error.")
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.")
        if response.status_code != 200:
            raise EcourtsProviderError(
                502, "The eCourts provider could not complete the request."
            )

        try:
            payload = response.json()
        except (ValueError, TypeError) as exc:
            raise EcourtsProviderError(502, "The eCourts provider returned malformed JSON.") from exc

        return _map_provider_response(payload, cnr)


# ---------------------------------------------------------------------------
# Response normalization
# Handles documented response envelope: { "data": {...}, "meta": {...} }
# ---------------------------------------------------------------------------

def _provider_text(value, field_name: str):
    if value is None:
        return None
    if not isinstance(value, (str, int, float)):
        raise EcourtsProviderError(502, "The eCourts provider returned an unexpected response.")
    text = str(value).strip()
    return text if text else None


def _first_provider_value(data: dict, keys):
    for key in keys:
        if key in data and data[key] is not None and data[key] != "":
            return data[key]
    return None


def _provider_string_list(value):
    if value is None:
        return []
    values = value if isinstance(value, list) else [value]
    out = []
    for item in values:
        text = _provider_text(item, "list")
        if text is not None:
            out.append(text)
    return out


def _map_orders(value):
    if value is None:
        return []
    if not isinstance(value, list):
        raise EcourtsProviderError(502, "The eCourts provider returned an unexpected response.")
    result = []
    for item in value:
        if not isinstance(item, dict):
            continue
        result.append(
            {
                "date": _provider_text(
                    _first_provider_value(item, ["date", "order_date", "hearing_date"]),
                    "orders.date",
                ),
                "detail": _provider_text(
                    _first_provider_value(item, ["detail", "business", "description"]),
                    "orders.detail",
                ),
            }
        )
    return result


def _extract_data(payload):
    """Extract the data object from the documented { data, meta } envelope."""
    if not isinstance(payload, dict):
        raise EcourtsProviderError(502, "The eCourts provider returned an unexpected response.")
    if "data" in payload:
        data = payload["data"]
    else:
        data = payload
    if not isinstance(data, dict):
        raise EcourtsProviderError(502, "The eCourts provider returned an unexpected response.")
    if not any(key in data for key in KNOWN_PROVIDER_FIELDS):
        raise EcourtsProviderError(502, "The eCourts provider returned an unexpected response.")
    return data


def _map_provider_response(payload, cnr: str) -> dict:
    data = _extract_data(payload)

    returned_cnr = _provider_text(_first_provider_value(data, ["cnr_number", "cnr"]), "cnr")
    if returned_cnr is not None and returned_cnr.upper() != cnr:
        raise EcourtsProviderError(502, "The eCourts provider returned a different case identifier.")

    return {
        "cnr": cnr,
        "case_number": _provider_text(
            _first_provider_value(data, ["case_no", "case_number"]), "case_number"
        ),
        "case_type": _provider_text(data.get("case_type"), "case_type"),
        "filing_date": _provider_text(data.get("filing_date"), "filing_date"),
        "registration_date": _provider_text(
            data.get("registration_date"), "registration_date"
        ),
        "status": _provider_text(
            _first_provider_value(data, ["case_status", "status"]), "status"
        ),
        "stage_of_case": _provider_text(
            _first_provider_value(data, ["stage_of_case", "stage"]), "stage_of_case"
        ),
        "court_name": _provider_text(data.get("court_name"), "court_name"),
        "court_number": _provider_text(
            _first_provider_value(data, ["court_number_chamber", "court_number"]),
            "court_number",
        ),
        "state": _provider_text(
            _first_provider_value(data, ["state_name", "state"]), "state"
        ),
        "district": _provider_text(
            _first_provider_value(data, ["district_name", "district"]), "district"
        ),
        "petitioner_names": _provider_string_list(
            _first_provider_value(data, ["petitioner", "petitioners", "petitioner_names"])
        ),
        "respondent_names": _provider_string_list(
            _first_provider_value(data, ["respondent", "respondents", "respondent_names"])
        ),
        "petitioner_advocate": _provider_text(data.get("petitioner_advocate"), "petitioner_advocate"),
        "respondent_advocate": _provider_text(data.get("respondent_advocate"), "respondent_advocate"),
        "next_hearing_date": _provider_text(data.get("next_hearing_date"), "next_hearing_date"),
        "last_hearing_date": _provider_text(data.get("last_hearing_date"), "last_hearing_date"),
        "orders": _map_orders(_first_provider_value(data, ["orders", "history"])),
        "acts": _provider_string_list(_first_provider_value(data, ["case_acts", "acts"])),
        "retrieved_at": _now_iso(),
        "provider": "ecourtsindia",
    }


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()
