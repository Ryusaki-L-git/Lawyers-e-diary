import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/models/service_catalogue_item.dart';

void main() {
  test('unknown service prices stay unknown instead of appearing free', () {
    final item = ServiceCatalogueItem.fromJson({
      'serviceId': 'act_section',
      'displayName': 'Act Section',
      'description': 'Retrieve one Act section from a supported source.',
      'tokenPrice': null,
      'billingUnit': 'per section',
      'available': false,
    });

    expect(item.serviceId, 'act_section');
    expect(item.tokenPrice, isNull);
    expect(item.available, isFalse);
  });

  test('service catalogue parses confirmed fractional token prices', () {
    final item = ServiceCatalogueItem.fromJson({
      'serviceId': 'smart_refresh',
      'displayName': 'Smart Refresh',
      'description': 'Refresh an owned case through LED.',
      'tokenPrice': 0.5,
      'billingUnit': 'per case',
      'available': true,
    });

    expect(item.tokenPrice, 0.5);
    expect(item.available, isTrue);
  });
}
