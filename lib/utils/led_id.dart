/// Utilities for LED (Lawyer's E-Diary) user ID formatting.
///
/// LED IDs use a single, globally increasing sequence with a year suffix
/// (Option A). The numeric component is zero-padded to four digits for
/// values below 10,000 but is allowed to grow naturally beyond four digits
/// once the sequence reaches 10,000. The sequence never resets per year.
library;

/// Formats an allocated sequence number and year into an LED ID.
///
/// Examples:
///   formatLedId(1, 2026)   -> '0001-2026'
///   formatLedId(9999, 2026) -> '9999-2026'
///   formatLedId(10000, 2027) -> '10000-2027'
String formatLedId(int sequence, int year) {
  if (sequence <= 0) {
    throw ArgumentError.value(sequence, 'sequence', 'Must be positive.');
  }
  if (year <= 0) {
    throw ArgumentError.value(year, 'year', 'Must be positive.');
  }
  return '${sequence.toString().padLeft(4, '0')}-$year';
}
