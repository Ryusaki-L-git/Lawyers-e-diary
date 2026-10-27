import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/services/subscription_service.dart';

void main() {
  group('SubscriptionInfo', () {
    test('reads the entitlement tier from server-owned subscription data', () {
      final expiry = Timestamp.fromDate(DateTime.utc(2027, 1, 1));
      final info = SubscriptionInfo.fromMap({
        'subscription': {
          'tier': 'cloud_subscriber',
          'expiry': expiry,
        },
      });

      expect(info.tier, SubscriptionTier.cloudSubscriber);
      expect(info.expiresAt, DateTime.utc(2027, 1, 1));
    });

    test('reads client sync metadata without requiring a subscription map', () {
      final syncedAt = Timestamp.fromDate(DateTime.utc(2026, 10, 27));
      final info = SubscriptionInfo.fromMap({'lastSyncedAt': syncedAt});

      expect(info.tier, SubscriptionTier.free);
      expect(info.lastSyncedAt, DateTime.utc(2026, 10, 27));
    });

    test('prefers the root sync timestamp over legacy nested metadata', () {
      final root = Timestamp.fromDate(DateTime.utc(2026, 10, 27, 12));
      final legacy = Timestamp.fromDate(DateTime.utc(2026, 10, 26));
      final info = SubscriptionInfo.fromMap({
        'lastSyncedAt': root,
        'subscription': {
          'tier': 'free',
          'lastSyncedAt': legacy,
        },
      });

      expect(info.lastSyncedAt, DateTime.utc(2026, 10, 27, 12));
    });
  });
}
