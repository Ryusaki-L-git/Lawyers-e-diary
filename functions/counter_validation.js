"use strict";

/**
 * Validates a persisted LED ID counter value.
 *
 * The global sequence is monotonic and must be a non-negative integer.
 * Fractional, negative, non-numeric or otherwise unsupported values are
 * rejected rather than silently truncated or normalized.
 *
 * @param {unknown} value
 * @returns {boolean}
 */
function isValidCounterValue(value) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

module.exports = { isValidCounterValue };
