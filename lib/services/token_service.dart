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
    final uri = base.resolve('/v1/tokens/me/ledger?limit=$limit');
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

  Future<Map<String, dynamic>> _requestBillingJson(
    String method,
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasScheme || !base.hasAuthority) {
      throw const TokenServiceException('JURIS is not configured for this build.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const TokenServiceException('Please sign in to LED again.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const TokenServiceException('Could not verify your LED session. Please sign in again.');
    }
    final requestUri = base.resolve(path);
    final HttpClientRequest request;
    if (method == 'PUT') {
      request = await _client.putUrl(requestUri).timeout(const Duration(seconds: 15));
    } else {
      request = await _client.getUrl(requestUri).timeout(const Duration(seconds: 15));
    }
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (payload != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
    }
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 401) {
      throw const TokenServiceException('Your LED session could not be authenticated. Please sign in again.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Could not update billing settings. Please try again later.';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
          message = decoded['detail'] as String;
        }
      } catch (_) {
        // Keep the safe fallback message for non-JSON errors.
      }
      throw TokenServiceException(message);
    }
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<BillingPreferences> fetchBillingPreferences() async {
    final data = await _requestBillingJson('GET', '/v1/billing/preferences');
    return BillingPreferences.fromJson(data);
  }

  Future<BillingPreferences> saveBillingPreferences({
    required String usageDeductionPriority,
    String? preferredTeamId,
  }) async {
    final data = await _requestBillingJson(
      'PUT',
      '/v1/billing/preferences',
      payload: {
        'usageDeductionPriority': usageDeductionPriority,
        'preferredTeamId': preferredTeamId,
      },
    );
    return BillingPreferences.fromJson(data);
  }

  Future<Map<String, dynamic>> fetchTeamPool(String teamId) async {
    if (teamId.trim().isEmpty) {
      throw const TokenServiceException('Choose a team first.');
    }
    return _requestBillingJson(
      'GET',
      '/v1/teams/${Uri.encodeComponent(teamId)}/pool',
    );
  }

  Future<Map<String, dynamic>> saveTeamMemberAllocation({
    required String teamId,
    required String memberUid,
    required int caseTokenLimitMinorUnits,
    required int jurisCreditLimitMinorUnits,
    required int storageLimitBytes,
  }) async {
    return _requestBillingJson(
      'PUT',
      '/v1/teams/${Uri.encodeComponent(teamId)}/pool/members/${Uri.encodeComponent(memberUid)}',
      payload: {
        'caseTokenLimitMinorUnits': caseTokenLimitMinorUnits,
        'jurisCreditLimitMinorUnits': jurisCreditLimitMinorUnits,
        'storageLimitBytes': storageLimitBytes,
      },
    );
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
  final double jurisTokens;

  double get credits => jurisTokens;
  String get creditsDisplay => credits.toStringAsFixed(2);
  double get caseTokens => caseTokensMinorUnits / 100.0;

  factory TokenBalance.fromJson(Map<String, dynamic> json) {
    // JURIS currently exposes whole-token balances in snake_case. LED's
    // presentation model uses hundredths so the existing two-decimal display
    // remains stable. Prefer the explicit minor-unit contract when supplied.
    final explicitMinorUnits = json['caseTokensMinorUnits'];
    final legacyWholeTokens = json['case_tokens'];
    final caseMinorUnits = explicitMinorUnits is num
        ? explicitMinorUnits.toInt()
        : legacyWholeTokens is num
        ? (legacyWholeTokens * 100).round()
        : 0;
    final explicitDisplay = json['caseTokensDisplay'];
    final display = explicitDisplay is String
        ? explicitDisplay
        : (caseMinorUnits / 100).toStringAsFixed(2);
    final creditsValue = json['credits'] ?? json['jurisTokens'] ?? json['juris_tokens'];
    return TokenBalance(
      caseTokensMinorUnits: caseMinorUnits,
      caseTokensDisplay: display,
      jurisTokens: creditsValue is num ? creditsValue.toDouble() : 0.0,
    );
  }
}

class BillingPreferences {
  const BillingPreferences({
    required this.usageDeductionPriority,
    required this.preferredTeamId,
  });

  final String usageDeductionPriority;
  final String? preferredTeamId;

  factory BillingPreferences.fromJson(Map<String, dynamic> json) {
    final priority = json['usageDeductionPriority'];
    final teamId = json['preferredTeamId'];
    return BillingPreferences(
      usageDeductionPriority: priority is String &&
              {'personal_first', 'team_first', 'ask'}.contains(priority)
          ? priority
          : 'personal_first',
      preferredTeamId: teamId is String && teamId.trim().isNotEmpty
          ? teamId
          : null,
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
    required this.tokenType,
  });

  final String transactionId;
  final int amountMinorUnits;
  final String direction;
  final String reason;
  final String createdAt;
  final int balanceAfterMinorUnits;
  final String tokenType;

  double get amountTokens => amountMinorUnits / 100.0;
  double get balanceAfterTokens => balanceAfterMinorUnits / 100.0;
  String get unitLabel => tokenType == 'case' ? 'Case Tokens' : 'Credits';

  factory UsageEntry.fromJson(Map<String, dynamic> json) {
    // The current JURIS ledger uses snake_case fields and whole-token
    // integer amounts. Keep compatibility with LED's previous minor-unit
    // camelCase payload while normalizing both into the UI model.
    final explicitAmountMinorUnits = json['amountMinorUnits'];
    final rawAmount = json['amount'] ?? json['amount_minor_units'];
    final amountMinorUnits = explicitAmountMinorUnits is num
        ? explicitAmountMinorUnits.toInt()
        : rawAmount is num
        ? (rawAmount * 100).round()
        : 0;
    final explicitBalanceMinorUnits = json['balanceAfterMinorUnits'];
    final rawBalance = json['balance_after'] ?? json['balanceAfter'];
    final balanceAfterMinorUnits = explicitBalanceMinorUnits is num
        ? explicitBalanceMinorUnits.toInt()
        : rawBalance is num
        ? (rawBalance * 100).round()
        : 0;
    final created = json['createdAt'] ?? json['created_at'];
    return UsageEntry(
      transactionId: json['transactionId'] as String? ??
          json['transaction_id'] as String? ??
          '',
      amountMinorUnits: amountMinorUnits,
      direction: json['direction'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      createdAt: created is String
          ? created
          : created?.toString() ?? '',
      balanceAfterMinorUnits: balanceAfterMinorUnits,
      tokenType: (json['tokenType'] ?? json['token_type'] ?? 'juris')
          .toString()
          .toLowerCase(),
    );
  }
}

class TokenServiceException implements Exception {
  const TokenServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
