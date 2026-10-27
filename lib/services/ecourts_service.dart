import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

class SmartRefreshResult {
  const SmartRefreshResult({required this.message, this.caseId, this.cnr});

  final String message;
  final String? caseId;
  final String? cnr;
}

class EcourtsService {
  EcourtsService({String? gatewayUrl})
      : _gatewayUrl = (gatewayUrl ?? const String.fromEnvironment('ECOURTS_GATEWAY_URL'))
            .trim();

  final String _gatewayUrl;
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

  Future<SmartRefreshResult> smartRefresh({required String caseId}) async {
    if (_gatewayUrl.isEmpty) {
      throw const EcourtsServiceException(
        'Smart Refresh is not configured for this build.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const EcourtsServiceException('Please sign in to LED again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const EcourtsServiceException('Could not verify your LED session.');
    }

    final base = Uri.tryParse(_gatewayUrl);
    if (base == null || !base.hasScheme || !base.hasAuthority || base.scheme != 'https') {
      throw const EcourtsServiceException('Smart Refresh URL is invalid.');
    }

    // The gateway is the authorized backend: it verifies the Firebase ID token,
    // re-derives the uid from the token (never trusting a client-supplied uid),
    // enforces case ownership/subscription against Firestore, calls eCourts, and
    // writes ecourts_data back to Firestore. The client sends only the case id.
    final uri = base.resolve('/v1/ecourts/cases/$caseId/refresh');
    final request = await _client.postUrl(uri).timeout(const Duration(seconds: 20));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode({}));

    final response = await request.close().timeout(const Duration(seconds: 60));
    final body = await response.transform(utf8.decoder).join();
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      throw const EcourtsServiceException('Invalid response from Smart Refresh.');
    }

    if (response.statusCode == 402) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic> &&
          detail['code'] == 'insufficient_tokens') {
        final required = detail['required'];
        final available = detail['available'];
        throw InsufficientCaseTokensException(
          required: required is num ? required.toDouble() : 0.5,
          available: available is num ? available.toDouble() : 0,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EcourtsServiceException(
        'Smart Refresh failed (HTTP ${response.statusCode}).',
      );
    }

    return SmartRefreshResult(
      message: (data['message'] as String?) ?? 'Smart Refresh submitted.',
      caseId: (data['caseId'] as String?) ?? caseId,
      cnr: (data['cnr'] as String?),
    );
  }

  /// Execute a priced service through the trusted LED gateway.
  /// The gateway re-authorizes every case ID and performs token billing.
  Future<Map<String, dynamic>> executePaidService({
    required String serviceId,
    required Map<String, dynamic> body,
  }) async {
    if (_gatewayUrl.isEmpty) {
      throw const EcourtsServiceException(
        'Case Intelligence services are not configured for this build.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const EcourtsServiceException('Please sign in to LED again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const EcourtsServiceException('Could not verify your LED session.');
    }
    final base = Uri.tryParse(_gatewayUrl);
    if (base == null ||
        !base.hasScheme ||
        !base.hasAuthority ||
        base.scheme != 'https') {
      throw const EcourtsServiceException('Case Intelligence gateway URL is invalid.');
    }

    final uri = base.resolve(
      '/v1/services/${Uri.encodeComponent(serviceId)}/execute',
    );
    final request = await _client
        .postUrl(uri)
        .timeout(const Duration(seconds: 20));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode(body));

    final response = await request.close().timeout(const Duration(seconds: 90));
    final rawBody = await response.transform(utf8.decoder).join();
    Map<String, dynamic> data = <String, dynamic>{};
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      throw const EcourtsServiceException(
        'Invalid response from Case Intelligence service.',
      );
    }

    if (response.statusCode == 402) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic> &&
          detail['code'] == 'insufficient_tokens') {
        final required = detail['required'];
        final available = detail['available'];
        throw InsufficientCaseTokensException(
          required: required is num ? required.toDouble() : 0,
          available: available is num ? available.toDouble() : 0,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = data['detail'];
      final message = detail is Map<String, dynamic>
          ? detail['message'] as String? ?? 'The service could not complete.'
          : detail is String
          ? detail
          : 'The service could not complete.';
      throw EcourtsServiceException(
        'Service failed (HTTP ${response.statusCode}): $message',
      );
    }
    return data;
  }

  void dispose() => _client.close(force: true);
}

class EcourtsServiceException implements Exception {
  const EcourtsServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InsufficientCaseTokensException extends EcourtsServiceException {
  const InsufficientCaseTokensException({
    required this.required,
    required this.available,
  }) : super('Not enough Case Tokens for Smart Refresh.');

  final double required;
  final double available;
}
