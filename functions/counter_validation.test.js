const { test } = require("node:test");
const assert = require("node:assert/strict");
const { isValidCounterValue } = require("./counter_validation");

test("accepts zero", () => {
  assert.equal(isValidCounterValue(0), true);
});

test("accepts positive integers", () => {
  assert.equal(isValidCounterValue(1), true);
  assert.equal(isValidCounterValue(9999), true);
});

test("rejects negative integers", () => {
  assert.equal(isValidCounterValue(-1), false);
});

test("rejects fractional values", () => {
  assert.equal(isValidCounterValue(1.5), false);
  assert.equal(isValidCounterValue(0.1), false);
});

test("rejects non-numbers", () => {
  assert.equal(isValidCounterValue("5"), false);
  assert.equal(isValidCounterValue(null), false);
  assert.equal(isValidCounterValue(undefined), false);
  assert.equal(isValidCounterValue(NaN), false);
  assert.equal(isValidCounterValue(Infinity), false);
});
