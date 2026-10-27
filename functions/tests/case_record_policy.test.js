"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { buildCnrOnlyCaseRecord } = require("../case_record_policy");

const ALLOWED_CLOUD_FIELDS = new Set([
  "ownerUid", "ownerLedId", "userId", "cuid", "cnrNumber", "caseNumber",
  "createdAt", "updatedAt", "lastUpdated", "cloudVersion", "cloudStorageMode",
]);

test("recipient registration contains only CNR and minimal sync ownership metadata", () => {
  const now = new Date("2026-10-27T12:00:00.000Z");
  const record = buildCnrOnlyCaseRecord({
    ownerUid: "recipient-uid", ownerLedId: "0042-2026", cnr: "abcd1234efgh5678", now,
  });
  assert.equal(record.ownerUid, "recipient-uid");
  assert.equal(record.userId, "recipient-uid");
  assert.equal(record.ownerLedId, "0042-2026");
  assert.equal(record.cuid, "ABCD1234EFGH5678");
  assert.equal(record.cnrNumber, record.cuid);
  assert.equal(record.caseNumber, record.cuid);
  assert.equal(record.cloudStorageMode, "cnr_only");
  assert.deepEqual([...Object.keys(record)].sort(), [...ALLOWED_CLOUD_FIELDS].filter((k) => Object.hasOwn(record, k)).sort());
  for (const privateField of ["caseTitle", "clientName", "clientPhone", "opponentName", "notes", "documents", "fees", "reminders", "ecourts_data"]) {
    assert.equal(Object.hasOwn(record, privateField), false, privateField + " must not be uploaded");
  }
});

test("recipient CNR-only registration rejects malformed CNR and invalid identity", () => {
  assert.throws(() => buildCnrOnlyCaseRecord({ ownerUid: "recipient-uid", cnr: "bad" }), /CNR/);
  assert.throws(() => buildCnrOnlyCaseRecord({ ownerUid: "", cnr: "ABCD1234EFGH5678" }), /UID/);
});
