import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/service_catalogue_item.dart';

class ServicesCatalogueService {
  ServicesCatalogueService({String? baseUrl})
      : _baseUrl = (baseUrl ?? const String.fromEnvironment('ECOURTS_GATEWAY_URL'))
            .trim();

  final String _baseUrl;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

  Future<List<ServiceCatalogueItem>> fetchCatalogue() async {
    if (_baseUrl.isEmpty) {
      throw const ServicesCatalogueException(
        'The LED services gateway is not configured for this build.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ServicesCatalogueException('Please sign in to LED again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const ServicesCatalogueException('Could not verify your LED session.');
    }

    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasScheme || !base.hasAuthority || base.scheme != 'https') {
      throw const ServicesCatalogueException('JURIS URL is invalid.');
    }

    final uri = base.resolve('/v1/services/catalogue');
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw ServicesCatalogueException('Could not load services (HTTP ${response.statusCode}).');
    }

    final decoded = jsonDecode(body);
    if (decoded is! List) {
      throw const ServicesCatalogueException('Invalid catalogue response.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ServiceCatalogueItem.fromJson)
        .toList();
  }

  void dispose() => _client.close(force: true);
}

class ServicesCatalogueException implements Exception {
  const ServicesCatalogueException(this.message);
  final String message;
  @override
  String toString() => message;
}
