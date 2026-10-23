import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

class TokenService {
  TokenService({String? baseUrl})
    : _baseUrl = (baseUrl ?? const String.fromEnvironment('JURIS_BASE_URL'))
          .trim();

  final String _baseUrl;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

  Future<TokenBalance> fetchBalance() async {
    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasScheme || !base.hasAuthority) {
      throw const TokenServiceException(
        'JURIS is not configured for this build.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const TokenServiceException('Please sign in to LED again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const TokenServiceException(
        'Could not verify your LED session. Please sign in again.',
      );
    }
    final uri = base.resolve('/v1/tokens/me');
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 401) {
      throw const TokenServiceException(
        'Your LED session could not be authenticated. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw const TokenServiceException(
        'Could not fetch token balance. Please try again later.',
      );
    }
    final decoded = jsonDecode(body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    return TokenBalance.fromJson(data);
  }

  Future<List<UsageEntry>> fetchUsageHistory({int limit = 50}) async {
    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasScheme || !base.hasAuthority) {
      throw const TokenServiceException(
        'JURIS is not configured for this build.',
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const TokenServiceException('Please sign in to LED again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const TokenServiceException(
        'Could not verify your LED session. Please sign in again.',
      );
    }
    final uri = base.resolve('/v1/ai/usage/me?limit=$limit');
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 401) {
      throw const TokenServiceException(
        'Your LED session could not be authenticated. Please sign in again.',
      );
    }
    if (response.statusCode != 200) {
      throw const TokenServiceException(
        'Could not fetch usage history. Please try again later.',
      );
    }
    final decoded = jsonDecode(body);
    final list = decoded is List ? decoded : <dynamic>[];
    return list
        .map((e) => UsageEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void dispose() => _client.close(force: true);
}

class TokenBalance {
  const TokenBalance({
    required this.caseTokensMinorUnits,
    required this.caseTokensDisplay,
    required this.jurisTokens,
  });

  final int caseTokensMinorUnits;
  final String caseTokensDisplay;
  final int jurisTokens;

  double get caseTokens => caseTokensMinorUnits / 100.0;

  factory TokenBalance.fromJson(Map<String, dynamic> json) {
    return TokenBalance(
      caseTokensMinorUnits:
          (json['caseTokensMinorUnits'] as num?)?.toInt() ?? 0,
      caseTokensDisplay: json['caseTokensDisplay'] as String? ?? '0.00',
      jurisTokens: (json['jurisTokens'] as num?)?.toInt() ?? 0,
    );
  }
}

class UsageEntry {
  const UsageEntry({
    required this.transactionId,
    required this.amountMinorUnits,
    required this.direction,
    required this.reason,
    required this.createdAt,
    required this.balanceAfterMinorUnits,
  });

  final String transactionId;
  final int amountMinorUnits;
  final String direction;
  final String reason;
  final String createdAt;
  final int balanceAfterMinorUnits;

  double get amountTokens => amountMinorUnits / 100.0;
  double get balanceAfterTokens => balanceAfterMinorUnits / 100.0;

  factory UsageEntry.fromJson(Map<String, dynamic> json) {
    return UsageEntry(
      transactionId: json['transactionId'] as String? ?? '',
      amountMinorUnits: (json['amountMinorUnits'] as num?)?.toInt() ?? 0,
      direction: json['direction'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      balanceAfterMinorUnits:
          (json['balanceAfterMinorUnits'] as num?)?.toInt() ?? 0,
    );
  }
}

class TokenServiceException implements Exception {
  const TokenServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
