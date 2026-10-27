import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class JurisService {
  JurisService({String? baseUrl})
    : _baseUrl = (baseUrl ?? const String.fromEnvironment('JURIS_BASE_URL'))
          .trim();

  final String _baseUrl;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

  Future<JurisChatResult> sendMessage({
    required String message,
    required String sessionId,
    String? activeCaseId,
    String? activeCaseTitle,
    List<String>? confirmedActionIds,
    String? selectedModel,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw const JurisServiceException('Please enter a message.');
    }
    if (_baseUrl.isEmpty) {
      throw const JurisServiceException(
        'JURIS is not configured for this build.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const JurisServiceException('Please sign in to LED again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const JurisServiceException(
        'Could not verify your LED session. Please sign in again.',
      );
    }

    final base = Uri.tryParse(_baseUrl);
    final isWindowsLocalDevelopment =
        defaultTargetPlatform == TargetPlatform.windows &&
        base != null &&
        base.scheme == 'http' &&
        (base.host == '127.0.0.1' || base.host == 'localhost');
    if (base == null ||
        !base.hasScheme ||
        !base.hasAuthority ||
        (base.scheme != 'https' && !isWindowsLocalDevelopment)) {
      throw const JurisServiceException(
        'JURIS must use HTTPS, except for localhost during Windows development.',
      );
    }
    final uri = base.resolve('/chat');
    final request = await _client
        .postUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(
      jsonEncode({
        'message': trimmed,
        'session_id': sessionId,
        'client_version': 'led-flutter',
        'context': {
          'current_screen': activeCaseId == null
              ? 'legal_research'
              : 'case_detail',
          if (activeCaseId != null && activeCaseId.trim().isNotEmpty)
            'active_case': {
              'resource_type': 'case',
              'resource_id': activeCaseId,
              'display_name': activeCaseTitle ?? '',
            },
        },
        'confirmed_action_ids': confirmedActionIds ?? [],
        if (selectedModel != null && selectedModel.trim().isNotEmpty)
          'ai': {
            'provider': 'gemini',
            'model': selectedModel.trim(),
            'mode': 'managed',
          },
      }),
    );

    final response = await request.close().timeout(const Duration(seconds: 50));
    final body = await response.transform(utf8.decoder).join();
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(body);
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      throw const JurisServiceException(
        'JURIS returned an invalid response. Please try again later.',
      );
    }

    if (response.statusCode == 401) {
      throw const JurisServiceException(
        'Your LED session could not be authenticated. Please sign in again.',
      );
    }
    if (response.statusCode == 403) {
      throw const JurisServiceException(
        'You are not authorized to use this JURIS request.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw JurisServiceException(
        'JURIS is temporarily unavailable (HTTP ${response.statusCode}).',
      );
    }
    final reply = (data['reply'] as String?)?.trim() ?? '';
    if (reply.isEmpty) {
      throw const JurisServiceException(
        'JURIS returned an empty response. Please retry.',
      );
    }

    Map<String, dynamic>? suggestedAction;
    final sa = data['suggested_action'];
    if (sa is Map<String, dynamic>) {
      suggestedAction = sa;
    }

    return JurisChatResult(
      reply: reply,
      sessionId: (data['session_id'] as String?) ?? sessionId,
      status: (data['status'] as String?) ?? 'ok',
      suggestedAction: suggestedAction,
    );
  }

  void dispose() => _client.close(force: true);
}

class JurisChatResult {
  const JurisChatResult({
    required this.reply,
    required this.sessionId,
    required this.status,
    this.suggestedAction,
  });

  final String reply;
  final String sessionId;
  final String status;
  final Map<String, dynamic>? suggestedAction;
}

class JurisServiceException implements Exception {
  const JurisServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
