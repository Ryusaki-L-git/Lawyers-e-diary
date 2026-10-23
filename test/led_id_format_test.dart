import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/utils/led_id.dart';

void main() {
  group('LED ID formatting (Option A global sequence)', () {
    test('pads single-digit sequence to four digits', () {
      expect(formatLedId(1, 2026), '0001-2026');
      expect(formatLedId(7, 2026), '0007-2026');
    });

    test('preserves four-digit sequence unchanged', () {
      expect(formatLedId(9999, 2026), '9999-2026');
    });

    test('allows numeric component to grow beyond four digits (no wrap)', () {
      expect(formatLedId(10000, 2026), '10000-2026');
      expect(formatLedId(10001, 2027), '10001-2027');
      expect(formatLedId(123456, 2026), '123456-2026');
    });

    test('year suffix follows the supplied year without resetting sequence', () {
      // Global sequence: 10000 in 2026 -> 10001 in 2027 (no reset).
      expect(formatLedId(10000, 2026), '10000-2026');
      expect(formatLedId(10001, 2027), '10001-2027');
    });

    test('rejects non-positive sequence', () {
      expect(() => formatLedId(0, 2026), throwsArgumentError);
      expect(() => formatLedId(-1, 2026), throwsArgumentError);
    });

    test('rejects non-positive year', () {
      expect(() => formatLedId(1, 0), throwsArgumentError);
      expect(() => formatLedId(1, -2026), throwsArgumentError);
    });
  });
}
