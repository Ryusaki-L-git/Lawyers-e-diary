"""Shared admission-result type for gateway request gating.

The gateway applies three independent gates before an outbound eCourts
provider call: the per-user refresh limit, the per-case concurrency lock,
and the global capacity cap. Each of them must be able to report three
distinct outcomes, and the HTTP response must never confuse them:

  ADMITTED     - the request may proceed.
  REJECTED     - a genuine limit was reached. This is a client-visible
                 rate-limit rejection and is reported as HTTP 429.
  UNAVAILABLE  - the shared state backing the gate could not be consulted
                 (for example a Firestore outage). This is an infrastructure
                 failure, not a rate limit, and is reported as HTTP 503 when
                 fail-closed behaviour is enabled.

A shared-state failure must never be reported as a rate-limit rejection:
doing so tells the client to back off for a window that was never reached
and hides a real outage behind a "slow down" message.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Optional


class AdmissionStatus(Enum):
    """Outcome of a gateway admission gate."""

    ADMITTED = "admitted"
    REJECTED = "rejected"
    UNAVAILABLE = "unavailable"


@dataclass(frozen=True)
class AdmissionResult:
    """Result of a gateway admission gate.

    `retry_after` is only meaningful for a REJECTED result and is set when
    the next eligible request time can be determined reliably.
    """

    status: AdmissionStatus
    retry_after: Optional[int] = None

    @property
    def admitted(self) -> bool:
        return self.status is AdmissionStatus.ADMITTED

    @property
    def rejected(self) -> bool:
        return self.status is AdmissionStatus.REJECTED

    @property
    def unavailable(self) -> bool:
        return self.status is AdmissionStatus.UNAVAILABLE

    @classmethod
    def admit(cls) -> "AdmissionResult":
        return cls(AdmissionStatus.ADMITTED)

    @classmethod
    def reject(cls, retry_after: Optional[int] = None) -> "AdmissionResult":
        return cls(AdmissionStatus.REJECTED, retry_after)

    @classmethod
    def unavailable_result(cls) -> "AdmissionResult":
        return cls(AdmissionStatus.UNAVAILABLE)
