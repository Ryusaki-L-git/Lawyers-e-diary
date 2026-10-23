const assert = require("node:assert/strict");

const AUTH_URL = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";
const FUNC_URL = "http://127.0.0.1:5001/demo-led-test/us-central1/allocateLedId";
const API_KEY = "fake-api-key";

async function createUser(email, password) {
  const res = await fetch(`${AUTH_URL}/accounts:signUp?key=${API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`signUp failed: ${JSON.stringify(data)}`);
  return data;
}

async function signIn(email, password) {
  const res = await fetch(`${AUTH_URL}/accounts:signInWithPassword?key=${API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`signIn failed: ${JSON.stringify(data)}`);
  return data;
}

async function callAllocate(idToken) {
  const res = await fetch(FUNC_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${idToken}`,
    },
    body: JSON.stringify({ data: {} }),
  });
  const data = await res.json();
  return { status: res.status, data };
}

const admin = require("firebase-admin");

// Initialize admin SDK pointing to emulator
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
admin.initializeApp({ projectId: "demo-led-test" });
const db = admin.firestore();

async function setProfile(uid, name) {
  await db.collection("users").doc(uid).set({
    name: name,
    advocateType: "Junior",
    profileCompleted: false,
  }, { merge: true });
}

async function getDoc(collection, id) {
  const snap = await db.collection(collection).doc(id).get();
  if (!snap.exists) return null;
  return { fields: snap.data(), id: snap.id };
}

async function getCounter() {
  const snap = await db.collection("metadata").doc("counters").get();
  if (!snap.exists) return 0;
  return snap.data().userCount || 0;
}

async function deleteDoc(collection, id) {
  await db.collection(collection).doc(id).delete();
}

// Test 1: First allocation
async function test1() {
  const email = `test1-${Date.now()}@test.com`;
  const password = "password123";
  const user = await createUser(email, password);
  await setProfile(user.localId, "Test User One");
  const result = await callAllocate(user.idToken);
  console.log("Test1 - First allocation:", JSON.stringify(result));
  assert.equal(result.status, 200);
  assert.equal(typeof result.data.result.ledId, "string");
  assert.match(result.data.result.ledId, /^\d{4,}-\d{4}$/);
  assert.equal(result.data.result.created, true);
  // Verify user doc
  const userDoc = await getDoc("users", user.localId);
  assert.equal(userDoc.fields.ledId, result.data.result.ledId);
  assert.equal(userDoc.fields.profileCompleted, true);
  // Verify directory
  const dirDoc = await getDoc("led_id_directory", result.data.result.ledId);
  assert.equal(dirDoc.fields.uid, user.localId);
  console.log("  PASS");
}

// Test 2: Retry returns same ID, no counter increment
async function test2() {
  const email = `test2-${Date.now()}@test.com`;
  const password = "password123";
  const user = await createUser(email, password);
  await setProfile(user.localId, "Test User Two");
  const r1 = await callAllocate(user.idToken);
  const counterBefore = await getCounter();
  const r2 = await callAllocate(user.idToken);
  const counterAfter = await getCounter();
  console.log("Test2 - Retry:", JSON.stringify(r2));
  assert.equal(r1.data.result.ledId, r2.data.result.ledId);
  assert.equal(r2.data.result.created, false);
  assert.equal(counterBefore, counterAfter);
  console.log("  PASS");
}

// Test 3: Missing profile name rejected
async function test3() {
  const email = `test3-${Date.now()}@test.com`;
  const password = "password123";
  const user = await createUser(email, password);
  // Don't set profile name (or set empty)
  await setProfile(user.localId, "");
  const counterBefore = await getCounter();
  const result = await callAllocate(user.idToken);
  console.log("Test3 - Missing name:", JSON.stringify(result));
  assert.notEqual(result.status, 200);
  const counterAfter = await getCounter();
  assert.equal(counterBefore, counterAfter);
  console.log("  PASS");
}

// Test 4: Two concurrent calls same user
async function test4() {
  const email = `test4-${Date.now()}@test.com`;
  const password = "password123";
  const user = await createUser(email, password);
  await setProfile(user.localId, "Concurrent User");
  const [r1, r2] = await Promise.all([
    callAllocate(user.idToken),
    callAllocate(user.idToken),
  ]);
  console.log("Test4 - Concurrent same user:", JSON.stringify(r1), JSON.stringify(r2));
  // Both should succeed and return same ID
  assert.equal(r1.status, 200);
  assert.equal(r2.status, 200);
  assert.equal(r1.data.result.ledId, r2.data.result.ledId);
  console.log("  PASS");
}

// Test 5: Different users get distinct IDs
async function test5() {
  const email1 = `test5a-${Date.now()}@test.com`;
  const email2 = `test5b-${Date.now()}@test.com`;
  const password = "password123";
  const u1 = await createUser(email1, password);
  const u2 = await createUser(email2, password);
  await setProfile(u1.localId, "User A");
  await setProfile(u2.localId, "User B");
  const [r1, r2] = await Promise.all([
    callAllocate(u1.idToken),
    callAllocate(u2.idToken),
  ]);
  console.log("Test5 - Different users:", JSON.stringify(r1), JSON.stringify(r2));
  assert.equal(r1.status, 200);
  assert.equal(r2.status, 200);
  assert.notEqual(r1.data.result.ledId, r2.data.result.ledId);
  console.log("  PASS");
}

// Test 6: Existing ID with missing directory
async function test6() {
  const email = `test6-${Date.now()}@test.com`;
  const password = "password123";
  const user = await createUser(email, password);
  await setProfile(user.localId, "Missing Dir User");
  const r1 = await callAllocate(user.idToken);
  const ledId = r1.data.result.ledId;
  // Delete directory entry via admin SDK
  await deleteDoc("led_id_directory", ledId);
  // Retry should recreate directory
  const r2 = await callAllocate(user.idToken);
  console.log("Test6 - Missing directory:", JSON.stringify(r2));
  assert.equal(r2.status, 200);
  assert.equal(r2.data.result.ledId, ledId);
  const dirDoc = await getDoc("led_id_directory", ledId);
  assert.ok(dirDoc, "directory entry should be recreated");
  console.log("  PASS");
}

// Test 7: Invalid counter value rejected
async function test7() {
  const email = `test7-${Date.now()}@test.com`;
  const password = "password123";
  const user = await createUser(email, password);
  await setProfile(user.localId, "Counter Test User");
  // Set counter to fractional
  await db.collection("metadata").doc("counters").set({ userCount: 5.5 });
  const result = await callAllocate(user.idToken);
  console.log("Test7 - Invalid counter:", JSON.stringify(result));
  assert.notEqual(result.status, 200);
  // Restore counter to a valid value
  await db.collection("metadata").doc("counters").set({ userCount: 100 });
  console.log("  PASS");
}

// Test 8: Directory owned by another UID not overwritten
async function test8() {
  const email = `test8-${Date.now()}@test.com`;
  const password = "password123";
  const user = await createUser(email, password);
  await setProfile(user.localId, "Ownership Test User");
  // First allocation
  const r1 = await callAllocate(user.idToken);
  const ledId = r1.data.result.ledId;
  // Tamper: set directory owner to another UID
  await db.collection("led_id_directory").doc(ledId).set({
    uid: "other-uid-123",
    ledId: ledId,
    name: "Other User",
    advocateType: "Senior",
    profileCompleted: true,
  });
  // Retry should fail (ownership mismatch)
  const r2 = await callAllocate(user.idToken);
  console.log("Test8 - Ownership:", JSON.stringify(r2));
  assert.notEqual(r2.status, 200);
  // Verify directory was NOT overwritten (still owned by other-uid)
  const dirDoc = await getDoc("led_id_directory", ledId);
  assert.equal(dirDoc.fields.uid, "other-uid-123");
  console.log("  PASS");
}
async function main() {
  console.log("=== allocateLedId Emulator Integration Tests ===\n");
  let passed = 0, failed = 0;
  const tests = [
    ["Test 1: First allocation", test1],
    ["Test 2: Retry returns same ID", test2],
    ["Test 3: Missing name rejected", test3],
    ["Test 4: Concurrent same user", test4],
    ["Test 5: Different users distinct IDs", test5],
    ["Test 6: Missing directory recreated", test6],
    ["Test 7: Invalid counter rejected", test7],
    ["Test 8: Directory ownership protected", test8],
  ];
  for (const [name, fn] of tests) {
    try {
      await fn();
      passed++;
    } catch (e) {
      console.log(`  FAIL: ${e.message}`);
      failed++;
    }
  }
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });
