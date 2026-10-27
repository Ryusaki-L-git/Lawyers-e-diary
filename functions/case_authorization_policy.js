"use strict";

/**
 * Resolve direct ownership without allowing a stale legacy userId to override
 * a canonical ownerUid. Team/assignment access is evaluated separately.
 */
function isDirectCaseOwner(uid, caseData) {
  if (typeof uid !== "string" || !uid) return false;
  if (typeof caseData?.ownerUid === "string" && caseData.ownerUid.trim()) {
    return caseData.ownerUid === uid;
  }
  return caseData?.userId === uid;
}

module.exports = { isDirectCaseOwner };
