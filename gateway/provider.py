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
import time
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

    def case_detail(self, cnr: str) -> dict:
        """Read case details for a CNR authorized by the LED gateway."""
        headers = {"Authorization": f"Bearer {self.api_token}", "Accept": "application/json"}
        try:
            with httpx.Client(timeout=self.timeout_seconds, follow_redirects=False) as client:
                response = client.get(f"{self.base_url.rstrip('/')}/api/partner/case/{cnr}", headers=headers)
        except httpx.TimeoutException as exc:
            raise EcourtsProviderError(504, "The eCourts provider timed out.") from exc
        except httpx.RequestError as exc:
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.") from exc
        if response.status_code != 200:
            _raise_provider_http_error(response.status_code)
        return _parse_json_response(response)

    def cause_list_search(self, params: dict) -> dict:
        """Search the documented cause-list endpoint with a bounded parameter set."""
        allowed = {
            "q", "date", "startDate", "endDate", "judge", "advocate", "state",
            "districtCode", "limit", "offset", "courtComplexCode", "court",
            "courtNo", "bench", "litigant", "listType", "includeCourtroom",
        }
        if not isinstance(params, dict) or not params or set(params) - allowed:
            raise ValueError("Cause-list filters are invalid.")
        headers = {"Authorization": f"Bearer {self.api_token}", "Accept": "application/json"}
        try:
            with httpx.Client(timeout=self.timeout_seconds, follow_redirects=False) as client:
                response = client.get(
                    f"{self.base_url.rstrip('/')}/api/partner/causelist/search",
                    headers=headers,
                    params=params,
                )
        except httpx.TimeoutException as exc:
            raise EcourtsProviderError(504, "The eCourts provider timed out.") from exc
        except httpx.RequestError as exc:
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.") from exc
        if response.status_code != 200:
            _raise_provider_http_error(response.status_code)
        return _parse_json_response(response)

    def cnr_cause_list_check(self, cnrs: list[str]) -> dict:
        """Check upcoming cause-list entries for a bounded list of authorized CNRs."""
        if not 1 <= len(cnrs) <= 100:
            raise ValueError("Provide between 1 and 100 case identifiers.")
        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        try:
            with httpx.Client(timeout=self.timeout_seconds, follow_redirects=False) as client:
                response = client.post(
                    f"{self.base_url.rstrip('/')}/api/partner/causelist/cnr/batch",
                    headers=headers,
                    json={"cnrs": cnrs},
                )
        except httpx.TimeoutException as exc:
            raise EcourtsProviderError(504, "The eCourts provider timed out.") from exc
        except httpx.RequestError as exc:
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.") from exc
        if response.status_code != 200:
            _raise_provider_http_error(response.status_code)
        return _parse_json_response(response)

    def order_download_pdf(self, cnr: str, filename: str, *, signed: bool = True) -> dict:
        """Retrieve the provider's order-download response for an authorized case."""
        if not filename.endswith(".pdf") or "/" in filename or "\\" in filename or ".." in filename:
            raise ValueError("Order filename is invalid.")
        headers = {"Authorization": f"Bearer {self.api_token}", "Accept": "application/json"}
        try:
            with httpx.Client(timeout=self.timeout_seconds, follow_redirects=False) as client:
                response = client.get(
                    f"{self.base_url.rstrip('/')}/api/partner/case/{cnr}/order/{filename}",
                    headers=headers,
                    params={"signed": str(signed).lower()},
                )
        except httpx.TimeoutException as exc:
            raise EcourtsProviderError(504, "The eCourts provider timed out.") from exc
        except httpx.RequestError as exc:
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.") from exc
        if response.status_code != 200:
            _raise_provider_http_error(response.status_code)
        return _parse_json_response(response)

    def order_ai_summary(self, cnr: str, filename: str) -> dict:
        """Retrieve the provider's AI-assisted order analysis."""
        if not filename.endswith(".pdf") or "/" in filename or "\\" in filename or ".." in filename:
            raise ValueError("Order filename is invalid.")
        headers = {"Authorization": f"Bearer {self.api_token}", "Accept": "application/json"}
        try:
            with httpx.Client(timeout=self.timeout_seconds, follow_redirects=False) as client:
                response = client.get(
                    f"{self.base_url.rstrip('/')}/api/partner/case/{cnr}/order-ai/{filename}",
                    headers=headers,
                )
        except httpx.TimeoutException as exc:
            raise EcourtsProviderError(504, "The eCourts provider timed out.") from exc
        except httpx.RequestError as exc:
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.") from exc
        if response.status_code != 200:
            _raise_provider_http_error(response.status_code)
        return _parse_json_response(response)

    def order_markdown_pdf(self, cnr: str, filename: str, *, signed: bool = True) -> dict:
        """Retrieve a watermarked order PDF and its extracted Markdown."""
        if not filename.endswith(".pdf") or "/" in filename or "\\" in filename or ".." in filename:
            raise ValueError("Order filename is invalid.")
        headers = {"Authorization": f"Bearer {self.api_token}", "Accept": "application/json"}
        try:
            with httpx.Client(timeout=max(self.timeout_seconds, 300), follow_redirects=False) as client:
                response = client.get(
                    f"{self.base_url.rstrip('/')}/api/partner/case/{cnr}/order-md/{filename}",
                    headers=headers,
                    params={"signed": str(signed).lower()},
                )
        except httpx.TimeoutException as exc:
            raise EcourtsProviderError(504, "The order conversion timed out.") from exc
        except httpx.RequestError as exc:
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.") from exc
        if response.status_code != 200:
            _raise_provider_http_error(response.status_code)
        return _parse_json_response(response)

    def bulk_case_refresh(self, cnrs: list[str]) -> dict:
        """Queue a bounded batch of case refreshes through the partner API."""
        if not 2 <= len(cnrs) <= 50:
            raise ValueError("Bulk refresh requires between 2 and 50 case identifiers.")
        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        try:
            with httpx.Client(timeout=self.timeout_seconds, follow_redirects=False) as client:
                response = client.post(
                    f"{self.base_url.rstrip('/')}/api/partner/case/bulk-refresh",
                    headers=headers,
                    json={"cnrs": cnrs},
                )
        except httpx.TimeoutException as exc:
            raise EcourtsProviderError(504, "The eCourts provider timed out.") from exc
        except httpx.RequestError as exc:
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.") from exc
        if response.status_code != 200:
            _raise_provider_http_error(response.status_code)
        return _parse_json_response(response)

    def refresh(self, cnr: str) -> dict:
        """Queue a provider refresh, wait for its status, then read the fresh case.

        eCourtsIndia's current partner API returns 202 Accepted for refresh;
        it does not return case details from the refresh POST itself.
        """
        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        base = self.base_url.rstrip("/")
        refresh_url = f"{base}{REFRESH_PATH.format(cnr=cnr)}"

        try:
            with httpx.Client(timeout=self.timeout_seconds, follow_redirects=False) as client:
                response = client.post(refresh_url, headers=headers, json={})
                if response.status_code == 202:
                    queued_payload = _parse_json_response(response)
                    queued_data = _extract_envelope_data(queued_payload)
                    if queued_data.get("status") not in {"QUEUED", "PENDING", "COMPLETED"}:
                        raise EcourtsProviderError(
                            502, "The eCourts provider returned an unexpected refresh status."
                        )

                    completed = queued_data.get("status") == "COMPLETED"
                    for _ in range(20):
                        if completed:
                            break
                        time.sleep(2)
                        status_response = client.post(
                            f"{base}/api/partner/case/bulk-refresh-status",
                            headers=headers,
                            json={"cnrs": [cnr]},
                        )
                        if status_response.status_code != 200:
                            _raise_provider_http_error(status_response.status_code)
                        status_payload = _parse_json_response(status_response)
                        status_data = _extract_envelope_data(status_payload)
                        results = status_data.get("results")
                        if not isinstance(results, list):
                            raise EcourtsProviderError(
                                502, "The eCourts provider returned an unexpected refresh status."
                            )
                        item = next(
                            (
                                entry for entry in results
                                if isinstance(entry, dict)
                                and str(entry.get("cnr", "")).upper() == cnr.upper()
                            ),
                            None,
                        )
                        if item is None:
                            continue
                        current_status = str(item.get("status", "")).upper()
                        if current_status == "COMPLETED":
                            completed = True
                            break
                        if current_status == "FAILED":
                            raise EcourtsProviderError(
                                502, "The eCourts provider could not refresh this case."
                            )
                        if current_status == "INVALID":
                            raise EcourtsProviderError(
                                400, "The eCourts provider rejected this CNR."
                            )

                    if not completed:
                        raise EcourtsProviderError(
                            504, "The case refresh is still processing. Please retry shortly."
                        )

                    detail_response = client.get(
                        f"{base}/api/partner/case/{cnr}",
                        headers=headers,
                    )
                    if detail_response.status_code != 200:
                        _raise_provider_http_error(detail_response.status_code)
                    return _map_case_detail(_parse_json_response(detail_response), cnr)

                if response.status_code != 200:
                    _raise_provider_http_error(response.status_code)
                payload = _parse_json_response(response)
                return _map_provider_response(payload, cnr)
        except EcourtsProviderError:
            raise
        except httpx.TimeoutException as exc:
            logger.warning("eCourts provider request timed out: %r", exc)
            raise EcourtsProviderError(504, "The eCourts provider timed out.") from exc
        except httpx.RequestError as exc:
            logger.warning("eCourts provider could not be reached: %r", exc)
            raise EcourtsProviderError(502, "The eCourts provider is unavailable.") from exc


def _raise_provider_http_error(status_code: int) -> None:
    if status_code == 404:
        raise EcourtsProviderError(404, "The case was not found in eCourts.")
    if status_code == 400:
        raise EcourtsProviderError(400, "The eCourts provider rejected this request.")
    if status_code in (401, 403):
        logger.error("eCourts provider rejected server authentication.")
        raise EcourtsProviderError(403, "The eCourts provider rejected its configured credentials.")
    if status_code == 429:
        raise EcourtsProviderError(429, "The eCourts provider rate limit was reached.")
    if status_code >= 500:
        logger.warning("eCourts provider returned a server error.")
        raise EcourtsProviderError(502, "The eCourts provider is unavailable.")
    raise EcourtsProviderError(502, "The eCourts provider could not complete the request.")


def _parse_json_response(response) -> dict:
    try:
        payload = response.json()
    except (ValueError, TypeError) as exc:
        raise EcourtsProviderError(502, "The eCourts provider returned malformed JSON.") from exc
    if not isinstance(payload, dict):
        raise EcourtsProviderError(502, "The eCourts provider returned an unexpected response.")
    return payload


def _extract_envelope_data(payload: dict) -> dict:
    data = payload.get("data", payload)
    if not isinstance(data, dict):
        raise EcourtsProviderError(502, "The eCourts provider returned an unexpected response.")
    return data


def _map_case_detail(payload: dict, cnr: str) -> dict:
    data = _extract_envelope_data(payload)
    case = data.get("courtCaseData", data)
    if not isinstance(case, dict) or not case:
        raise EcourtsProviderError(502, "The eCourts provider returned an unexpected case record.")

    def party_names(value, side: str) -> list[str]:
        if not isinstance(value, list):
            value = [value] if value is not None else []
        names = []
        for item in value:
            if isinstance(item, str) and item.strip():
                names.append(item.strip())
            elif isinstance(item, dict):
                item_side = str(item.get("side", "")).lower()
                name = item.get("name") or item.get("partyName")
                if name and (not item_side or item_side == side):
                    names.append(str(name).strip())
        return names

    parties = case.get("parties") or data.get("parties")
    petitioners = case.get("petitioners")
    respondents = case.get("respondents")
    if isinstance(parties, list):
        petitioners = petitioners or [p for p in parties if isinstance(p, dict) and str(p.get("side", "")).lower() == "petitioner"]
        respondents = respondents or [p for p in parties if isinstance(p, dict) and str(p.get("side", "")).lower() == "respondent"]

    orders = case.get("judgmentOrders") or case.get("interimOrders") or case.get("orders") or []
    mapped_orders = []
    if isinstance(orders, list):
        for order in orders:
            if not isinstance(order, dict):
                continue
            mapped_orders.append({
                "date": _provider_text(
                    _first_provider_value(order, ["orderDate", "date", "hearingDate"]),
                    "orders.date",
                ),
                "detail": _provider_text(
                    _first_provider_value(order, ["title", "orderType", "description", "orderUrl"]),
                    "orders.detail",
                ),
            })

    acts = case.get("acts") or case.get("caseActs") or []
    if not acts and isinstance(case.get("provisions"), list):
        acts = [
            item.get("act") or item.get("act_as_written")
            for item in case["provisions"]
            if isinstance(item, dict)
        ]

    returned_cnr = _provider_text(
        _first_provider_value(case, ["cnr", "cnrNumber", "cnr_number"]), "cnr"
    )
    if returned_cnr is not None and returned_cnr.upper() != cnr.upper():
        raise EcourtsProviderError(502, "The eCourts provider returned a different case identifier.")

    return {
        "cnr": cnr.upper(),
        "case_number": _provider_text(
            _first_provider_value(case, ["caseNumber", "registrationNumber", "cnrCaseNumber"]),
            "case_number",
        ),
        "case_type": _provider_text(
            _first_provider_value(case, ["caseType", "caseTypeRaw", "caseTypeSub"]),
            "case_type",
        ),
        "filing_date": _provider_text(case.get("filingDate"), "filing_date"),
        "registration_date": _provider_text(case.get("registrationDate"), "registration_date"),
        "status": _provider_text(_first_provider_value(case, ["caseStatus", "status"]), "status"),
        "stage_of_case": _provider_text(_first_provider_value(case, ["stage", "stageOfCase"]), "stage_of_case"),
        "court_name": _provider_text(_first_provider_value(case, ["courtName", "court"]), "court_name"),
        "court_number": _provider_text(_first_provider_value(case, ["courtNo", "courtNumber"]), "court_number"),
        "state": _provider_text(_first_provider_value(case, ["state", "stateName"]), "state"),
        "district": _provider_text(_first_provider_value(case, ["district", "districtName"]), "district"),
        "petitioner_names": party_names(petitioners, "petitioner"),
        "respondent_names": party_names(respondents, "respondent"),
        "petitioner_advocate": _provider_text(case.get("petitionerAdvocate"), "petitioner_advocate"),
        "respondent_advocate": _provider_text(case.get("respondentAdvocate"), "respondent_advocate"),
        "next_hearing_date": _provider_text(case.get("nextHearingDate"), "next_hearing_date"),
        "last_hearing_date": _provider_text(case.get("lastHearingDate"), "last_hearing_date"),
        "orders": mapped_orders,
        "acts": _provider_string_list(acts),
        "retrieved_at": _now_iso(),
        "provider": "ecourtsindia",
    }



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
