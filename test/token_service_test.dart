import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/services/token_service.dart';

void main() {
  group('TokenBalance.fromJson', () {
    test('normalizes JURIS snake_case whole-token balances', () {
      final balance = TokenBalance.fromJson({
        'juris_tokens': 7,
        'case_tokens': 199,
      });

      expect(balance.jurisTokens, 7);
      expect(balance.caseTokensMinorUnits, 19900);
      expect(balance.caseTokensDisplay, '199.00');
      expect(balance.caseTokens, 199.0);
    });

    test('prefers the explicit LED minor-unit response contract', () {
      final balance = TokenBalance.fromJson({
        'jurisTokens': 3,
        'caseTokensMinorUnits': 1250,
        'caseTokensDisplay': '12.50',
      });

      expect(balance.jurisTokens, 3);
      expect(balance.caseTokensMinorUnits, 1250);
      expect(balance.caseTokensDisplay, '12.50');
      expect(balance.caseTokens, 12.5);
    });
  });

  group('UsageEntry.fromJson', () {
    test('normalizes the current JURIS snake_case ledger contract', () {
      final entry = UsageEntry.fromJson({
        'transaction_id': 'case:refresh-1',
        'amount': 2,
        'direction': 'debit',
        'reason': 'Case detail',
        'created_at': '2026-10-27T10:00:00+00:00',
        'balance_after': 17,
      });

      expect(entry.transactionId, 'case:refresh-1');
      expect(entry.amountMinorUnits, 200);
      expect(entry.amountTokens, 2.0);
      expect(entry.direction, 'debit');
      expect(entry.reason, 'Case detail');
      expect(entry.createdAt, '2026-10-27T10:00:00+00:00');
      expect(entry.balanceAfterMinorUnits, 1700);
      expect(entry.balanceAfterTokens, 17.0);
    });

    test('preserves the legacy LED minor-unit ledger contract', () {
      final entry = UsageEntry.fromJson({
        'transactionId': 'legacy-1',
        'amountMinorUnits': 50,
        'direction': 'debit',
        'reason': 'Smart Refresh',
        'createdAt': '2026-10-27T10:00:00Z',
        'balanceAfterMinorUnits': 1950,
      });

      expect(entry.amountTokens, 0.5);
      expect(entry.balanceAfterTokens, 19.5);
    });
  });
}
