import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Best-effort LED ID allocation. IDs are assigned only by the authenticated
/// gateway; this client never counts users or chooses an ID locally.
class LedIdAllocationService {
  static const _gatewayUrl =
      String.fromEnvironment('ECOURTS_GATEWAY_URL');
  static const _retryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(seconds: 90),
  ];

  /// Makes up to five attempts over a few minutes, without blocking onboarding.
  /// The gateway is idempotent: a retry for the same UID reuses its ID.
  Future<void> allocateWithRetries(User user) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final assigned = await _allocateOnce(user);
        if (assigned) return;
      } catch (error) {
        debugPrint('LED ID allocation attempt ${attempt + 1} failed: $error');
      }

      if (attempt < _retryDelays.length) {
        await Future<void>.delayed(_retryDelays[attempt]);
      }
    }

    debugPrint('LED ID remains pending; it can be retried on the next app start.');
  }

  Future<bool> _allocateOnce(User user) async {
    final configuredUrl = _gatewayUrl.trim();
    if (configuredUrl.isEmpty) {
      throw StateError('ECOURTS_GATEWAY_URL is not configured.');
    }

    final base = Uri.tryParse(configuredUrl);
    if (base == null ||
        !base.hasScheme ||
        !base.hasAuthority ||
        (base.scheme != 'https' && base.scheme != 'http')) {
      throw StateError('The LED gateway URL is invalid.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Firebase could not provide an ID token.');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .postUrl(base.resolve('/v1/led/allocate-id'))
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode(<String, Object?>{}));

      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'LED allocation returned HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> ||
          decoded['ledId'] is! String ||
          (decoded['ledId'] as String).trim().isEmpty) {
        throw const FormatException('Gateway response did not contain an LED ID.');
      }
      return true;
    } finally {
      client.close(force: true);
    }
  }
}
