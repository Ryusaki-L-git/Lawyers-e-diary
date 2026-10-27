"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { isDirectCaseOwner } = require("../case_authorization_policy");

test("canonical ownerUid overrides a conflicting legacy userId", () => {
  const legacyTransferRecord = {
    ownerUid: "source-advocate",
    userId: "recipient-advocate",
  };
  assert.equal(isDirectCaseOwner("source-advocate", legacyTransferRecord), true);
  assert.equal(isDirectCaseOwner("recipient-advocate", legacyTransferRecord), false);
});

test("legacy userId remains usable only when canonical ownerUid is absent", () => {
  assert.equal(isDirectCaseOwner("legacy-owner", { userId: "legacy-owner" }), true);
  assert.equal(isDirectCaseOwner("other-user", { userId: "legacy-owner" }), false);
  assert.equal(isDirectCaseOwner("legacy-owner", { ownerUid: null, userId: "legacy-owner" }), true);
});
