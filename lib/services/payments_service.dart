import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentsService {
  PaymentsService({String? baseUrl})
      : _baseUrl = (baseUrl ?? const String.fromEnvironment('ECOURTS_GATEWAY_URL'))
            .trim();

  final String _baseUrl;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

  Uri _base() {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      throw const PaymentsServiceException(
        'Secure LED checkout is not configured for this build.',
      );
    }
    return uri;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? payload,
    bool authenticated = true,
  }) async {
    final uri = _base().resolve(path);
    final HttpClientRequest request = method == 'POST'
        ? await _client.postUrl(uri).timeout(const Duration(seconds: 15))
        : await _client.getUrl(uri).timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (authenticated) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const PaymentsServiceException('Please sign in to LED again.');
      }
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        throw const PaymentsServiceException(
          'Could not verify your LED session. Please sign in again.',
        );
      }
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    if (payload != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
    }
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await response.transform(utf8.decoder).join();
    Map<String, dynamic> decoded = <String, dynamic>{};
    if (body.trim().isNotEmpty) {
      try {
        final value = jsonDecode(body);
        if (value is Map<String, dynamic>) decoded = value;
      } on FormatException {
        throw const PaymentsServiceException(
          'The checkout service returned an invalid response.',
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded['detail'];
      throw PaymentsServiceException(
        detail is String && detail.isNotEmpty
            ? detail
            : 'Checkout is unavailable (HTTP ${response.statusCode}).',
      );
    }
    return decoded;
  }

  Future<List<PaymentPack>> fetchPacks() async {
    final data = await _request(
      'GET',
      '/v1/payments/packs',
      authenticated: false,
    );
    final raw = data['packs'];
    if (raw is! List) {
      throw const PaymentsServiceException('The checkout pack list is invalid.');
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PaymentPack.fromJson)
        .toList();
  }

  Future<HostedPaymentLink> createHostedLink(String packId) async {
    final data = await _request(
      'POST',
      '/v1/payments/links',
      payload: {'packId': packId},
    );
    return HostedPaymentLink.fromJson(data);
  }

  Future<PaymentLinkStatus> getHostedLinkStatus(String referenceId) async {
    return PaymentLinkStatus.fromJson(
      await _request(
        'GET',
        '/v1/payments/links/${Uri.encodeComponent(referenceId)}',
      ),
    );
  }

  Future<void> openCheckout(String shortUrl) async {
    final uri = Uri.tryParse(shortUrl);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      throw const PaymentsServiceException(
        'The checkout provider returned an invalid secure URL.',
      );
    }
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const PaymentsServiceException(
        'Could not open the secure checkout page.',
      );
    }
  }

  void dispose() => _client.close(force: true);
}

class PaymentPack {
  const PaymentPack({
    required this.id,
    required this.label,
    required this.amountPaise,
    required this.tokenType,
    required this.grantUnits,
  });

  final String id;
  final String label;
  final int amountPaise;
  final String tokenType;
  final int grantUnits;

  String get amountLabel => '₹${(amountPaise / 100).toStringAsFixed(0)}';

  factory PaymentPack.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    final amount = json['amountPaise'];
    final tokenType = json['tokenType'];
    final units = json['grantUnits'];
    if (id is! String ||
        label is! String ||
        amount is! num ||
        tokenType is! String ||
        units is! num ||
        !{'juris', 'case'}.contains(tokenType)) {
      throw const PaymentsServiceException('A checkout pack is invalid.');
    }
    return PaymentPack(
      id: id,
      label: label,
      amountPaise: amount.toInt(),
      tokenType: tokenType,
      grantUnits: units.toInt(),
    );
  }
}

class HostedPaymentLink {
  const HostedPaymentLink({
    required this.referenceId,
    required this.shortUrl,
  });

  final String referenceId;
  final String shortUrl;

  factory HostedPaymentLink.fromJson(Map<String, dynamic> json) {
    final referenceId = json['referenceId'];
    final shortUrl = json['shortUrl'];
    if (referenceId is! String || shortUrl is! String) {
      throw const PaymentsServiceException(
        'The checkout provider did not return a valid payment link.',
      );
    }
    return HostedPaymentLink(referenceId: referenceId, shortUrl: shortUrl);
  }
}

class PaymentLinkStatus {
  const PaymentLinkStatus({
    required this.status,
    required this.tokenType,
    required this.creditedUnits,
  });

  final String status;
  final String? tokenType;
  final int creditedUnits;

  factory PaymentLinkStatus.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final units = json['creditedUnits'];
    if (status is! String) {
      throw const PaymentsServiceException(
        'The payment status response is invalid.',
      );
    }
    return PaymentLinkStatus(
      status: status,
      tokenType: json['tokenType'] as String?,
      creditedUnits: units is num ? units.toInt() : 0,
    );
  }
}

class PaymentsServiceException implements Exception {
  const PaymentsServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
