"use strict";

const CNR_PATTERN = /^[A-Z0-9]{16}$/;

/** Build the only case fields allowed in a Free user cloud registration. */
function buildCnrOnlyCaseRecord({ ownerUid, ownerLedId, cnr, now = new Date(), cloudVersion = 1 }) {
  if (typeof ownerUid !== "string" || ownerUid.trim().length === 0 || ownerUid.includes("/")) {
    throw new TypeError("A valid owner UID is required.");
  }
  if (typeof cnr !== "string" || !CNR_PATTERN.test(cnr.trim().toUpperCase())) {
    throw new TypeError("A valid 16-character CNR is required.");
  }
  if (!(now instanceof Date) || Number.isNaN(now.getTime())) {
    throw new TypeError("A valid creation timestamp is required.");
  }
  if (!Number.isSafeInteger(cloudVersion) || cloudVersion < 1) {
    throw new TypeError("Cloud version must be a positive integer.");
  }

  const normalizedCnr = cnr.trim().toUpperCase();
  const uid = ownerUid.trim();
  const record = {
    ownerUid: uid,
    userId: uid,
    cuid: normalizedCnr,
    cnrNumber: normalizedCnr,
    caseNumber: normalizedCnr,
    createdAt: now,
    updatedAt: now,
    lastUpdated: now,
    cloudVersion,
    cloudStorageMode: "cnr_only",
  };
  if (typeof ownerLedId === "string" && ownerLedId.trim()) {
    record.ownerLedId = ownerLedId.trim();
  }
  return record;
}

module.exports = { buildCnrOnlyCaseRecord };
