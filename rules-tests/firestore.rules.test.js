"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const { initializeTestEnvironment, assertFails, assertSucceeds } = require("@firebase/rules-unit-testing");
const { collection, doc, getDoc, getDocs, setDoc, writeBatch, Timestamp } = require("firebase/firestore");

const PROJECT_ID = "demo-led-case-privacy";
const CNR = "ABCD1234EFGH5678";
const now = () => Timestamp.fromDate(new Date("2026-10-27T12:00:00.000Z"));
let testEnv;

async function createRegisteredCase(db, caseId, data) {
  const batch = writeBatch(db);
  batch.set(doc(db, `cases/${caseId}`), data);
  batch.set(doc(db, `users/${data.ownerUid}/case_cuid_registry/${data.cuid}`), {
    uid: data.ownerUid, cuid: data.cuid, caseId, updatedAt: now(),
  });
  await batch.commit();
}

function freeStub(uid, caseId) {
  return {
    ownerUid: uid, userId: uid, cuid: CNR, cnrNumber: CNR, caseNumber: CNR,
    createdAt: now(), updatedAt: now(), lastUpdated: now(), cloudVersion: 1,
    cloudStorageMode: "cnr_only",
  };
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8") },
  });
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users/user-subscriber"), { subscription: { tier: "cloud_subscriber" } });
    await setDoc(doc(db, "led_id_directory/0042-2026"), { uid: "user-b", name: "Advocate B", profileCompleted: true });
  });
});

test.after(async () => { await testEnv.cleanup(); });

test("Free users may create a minimal CNR-only cloud registration", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();
  await assertSucceeds(createRegisteredCase(db, "case-a", freeStub("user-a", "case-a")));
});

test("Free users cannot upload private case fields to the cloud", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();
  await assertFails(createRegisteredCase(db, "case-private", {
    ...freeStub("user-a", "case-private"), caseTitle: "Private client case",
    clientName: "Confidential", notes: ["Private note"], documents: [{ name: "brief.pdf" }],
  }));
});

test("Cloud Subscribers may store their own full case record", async () => {
  const db = testEnv.authenticatedContext("user-subscriber").firestore();
  await assertSucceeds(createRegisteredCase(db, "subscriber-case", {
    ownerUid: "user-subscriber", userId: "user-subscriber", cuid: CNR,
    cnrNumber: CNR, caseNumber: CNR, cloudStorageMode: "full",
    caseTitle: "Subscriber private case", clientName: "Client A",
    notes: ["Private note"], documents: [], status: "active",
  }));
});

test("case owner and CNR identity cannot be reassigned by a client update", async () => {
  const db = testEnv.authenticatedContext("user-subscriber").firestore();
  await createRegisteredCase(db, "immutable-case", {
    ownerUid: "user-subscriber", userId: "user-subscriber",
    ownerLedId: "0001-2026", cuid: CNR,
    cnrNumber: CNR, caseNumber: CNR, cloudStorageMode: "full",
    caseTitle: "Private subscriber case", clientName: "Client A",
  });

  await assertFails(setDoc(doc(db, "cases/immutable-case"), {
    ownerUid: "user-b", userId: "user-b", cuid: CNR,
    cnrNumber: CNR, caseNumber: CNR, cloudStorageMode: "full",
    caseTitle: "Private subscriber case", clientName: "Client A",
  }));

  await assertFails(setDoc(doc(db, "cases/immutable-case"), {
    ownerUid: "user-subscriber", userId: "user-subscriber",
    cuid: "WXYZ1234EFGH5678", cnrNumber: "WXYZ1234EFGH5678",
    caseNumber: "WXYZ1234EFGH5678", cloudStorageMode: "full",
    caseTitle: "Private subscriber case", clientName: "Client A",
  }));

  await assertFails(setDoc(doc(db, "cases/immutable-case"), {
    ownerUid: "user-subscriber", userId: "user-subscriber",
    ownerLedId: "0002-2026", cuid: CNR,
    cnrNumber: CNR, caseNumber: CNR, cloudStorageMode: "full",
    caseTitle: "Private subscriber case", clientName: "Client A",
  }));
});

test("a stale legacy userId cannot expose a case owned by another advocate", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/user-a"), {
      subscription: { tier: "cloud_subscriber" },
    });
    await setDoc(doc(context.firestore(), "users/user-b"), {
      subscription: { tier: "cloud_subscriber" },
    });
    await setDoc(doc(context.firestore(), "cases/legacy-mismatched-owner"), {
      ownerUid: "user-a",
      userId: "user-b",
      cuid: CNR,
      cnrNumber: CNR,
      caseNumber: CNR,
      cloudStorageMode: "full",
      caseTitle: "Owner A confidential case",
      clientName: "Private client A",
    });
  });

  const dbA = testEnv.authenticatedContext("user-a").firestore();
  const dbB = testEnv.authenticatedContext("user-b").firestore();
  await assertSucceeds(getDoc(doc(dbA, "cases/legacy-mismatched-owner")));
  await assertFails(getDoc(doc(dbB, "cases/legacy-mismatched-owner")));
});

test("the same CNR can exist in two independent advocate records", async () => {
  const dbA = testEnv.authenticatedContext("user-a").firestore();
  const dbB = testEnv.authenticatedContext("user-b").firestore();
  await assertSucceeds(createRegisteredCase(dbA, "a-record", freeStub("user-a", "a-record")));
  await assertSucceeds(createRegisteredCase(dbB, "b-record", freeStub("user-b", "b-record")));
  await assertSucceeds(getDoc(doc(dbA, "cases/a-record")));
  await assertSucceeds(getDoc(doc(dbB, "cases/b-record")));
  await assertFails(getDoc(doc(dbA, "cases/b-record")));
  await assertFails(getDoc(doc(dbB, "cases/a-record")));
});

test("CNR registry can be created atomically only for its matching owned case", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();
  const batch = writeBatch(db);
  batch.set(doc(db, "cases/case-a"), freeStub("user-a", "case-a"));
  batch.set(doc(db, `users/user-a/case_cuid_registry/${CNR}`), { uid: "user-a", cuid: CNR, caseId: "case-a", updatedAt: now() });
  await assertSucceeds(batch.commit());
});

test("a CNR-only transfer stub can be re-keyed atomically to a pending local record", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();
  await createRegisteredCase(db, "transfer-stub", freeStub("user-a", "transfer-stub"));
  const batch = writeBatch(db);
  batch.delete(doc(db, "cases/transfer-stub"));
  batch.set(doc(db, "cases/local-case"), freeStub("user-a", "local-case"));
  batch.update(doc(db, `users/user-a/case_cuid_registry/${CNR}`), {
    uid: "user-a", cuid: CNR, caseId: "local-case", updatedAt: now(),
  });
  await assertSucceeds(batch.commit());
  await assertFails(getDoc(doc(db, "cases/transfer-stub")));
  await assertSucceeds(getDoc(doc(db, "cases/local-case")));
});

test("a full cloud record cannot be replaced by a different case ID", async () => {
  const db = testEnv.authenticatedContext("user-subscriber").firestore();
  await createRegisteredCase(db, "full-case", {
    ownerUid: "user-subscriber", userId: "user-subscriber", cuid: CNR,
    cnrNumber: CNR, caseNumber: CNR, cloudStorageMode: "full",
    caseTitle: "Private subscriber case", clientName: "Client A",
  });
  const batch = writeBatch(db);
  batch.delete(doc(db, "cases/full-case"));
  batch.set(doc(db, "cases/other-case"), freeStub("user-subscriber", "other-case"));
  batch.update(doc(db, `users/user-subscriber/case_cuid_registry/${CNR}`), {
    uid: "user-subscriber", cuid: CNR, caseId: "other-case", updatedAt: now(),
  });
  await assertFails(batch.commit());
});

test("CNR registry cannot point to a missing or foreign case", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();
  await assertFails(setDoc(doc(db, `users/user-a/case_cuid_registry/${CNR}`), {
    uid: "user-a", cuid: CNR, caseId: "missing-case", updatedAt: now(),
  }));
  await assertFails(setDoc(doc(db, `users/user-b/case_cuid_registry/${CNR}`), {
    uid: "user-b", cuid: CNR, caseId: "case-a", updatedAt: now(),
  }));
});

test("LED-ID directory allows known-ID lookup but blocks global enumeration", async () => {
  const db = testEnv.authenticatedContext("user-a").firestore();
  await assertSucceeds(getDoc(doc(db, "led_id_directory/0042-2026")));
  await assertFails(getDocs(collection(db, "led_id_directory")));
});
