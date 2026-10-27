from __future__ import annotations

from collections import deque
from types import SimpleNamespace

import httpx
import pytest

from gateway.provider import EcourtsProvider

CNR = "ABCD1234EFGH5678"


class FakeResponse:
    def __init__(self, status_code: int, payload: dict):
        self.status_code = status_code
        self._payload = payload

    def json(self):
        return self._payload


def test_async_refresh_waits_for_completion_then_reads_case(monkeypatch):
    posts = deque([
        FakeResponse(202, {"data": {"cnr": CNR, "status": "QUEUED"}}),
        FakeResponse(200, {"data": {"results": [{"cnr": CNR, "status": "COMPLETED"}]}}),
    ])
    requests = []

    class FakeClient:
        def __init__(self, timeout=None, follow_redirects=False):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def post(self, url, headers, json=None):
            requests.append(("POST", url, json))
            return posts.popleft()

        def get(self, url, headers):
            requests.append(("GET", url, None))
            return FakeResponse(200, {
                "data": {
                    "courtCaseData": {
                        "cnr": CNR,
                        "caseNumber": "C-1",
                        "caseStatus": "PENDING",
                        "courtName": "District Court",
                        "nextHearingDate": "2026-11-01",
                    }
                }
            })

    monkeypatch.setattr("gateway.provider.httpx.Client", FakeClient)
    monkeypatch.setattr("gateway.provider.time.sleep", lambda _: None, raising=False)

    provider = EcourtsProvider(api_token="server-secret", base_url="https://example.com")
    result = provider.refresh(CNR)

    assert result["cnr"] == CNR
    assert result["case_number"] == "C-1"
    assert result["status"] == "PENDING"
    assert result["court_name"] == "District Court"
    assert result["next_hearing_date"] == "2026-11-01"
    assert requests[0] == (
        "POST",
        f"https://example.com/api/partner/case/{CNR}/refresh",
        {},
    )
    assert requests[1][1] == "https://example.com/api/partner/case/bulk-refresh-status"
    assert requests[2] == (
        "GET",
        f"https://example.com/api/partner/case/{CNR}",
        None,
    )
