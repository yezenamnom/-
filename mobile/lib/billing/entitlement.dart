import 'dart:convert';

import '../config/config_verifier.dart';

/// "Remove ads" entitlement. Only ever created from an envelope signed by
/// our server after it verified the purchase with Apple/Google; a local flag
/// or a client-side receipt check never grants it.
class AdFreeEntitlement {
  const AdFreeEntitlement({
    required this.productId,
    required this.platform,
    required this.expiresAt,
    required this.status,
  });

  final String productId;
  final String platform;
  final DateTime expiresAt;

  /// active | grace | canceled (still valid until expiry) | expired | revoked
  final String status;

  bool isValidAt(DateTime now) =>
      (status == 'active' || status == 'grace' || status == 'canceled') &&
      now.toUtc().isBefore(expiresAt);

  static AdFreeEntitlement? fromPayload(String payloadJson) {
    try {
      final m = jsonDecode(payloadJson);
      if (m is! Map || m['type'] != 'ad_free_entitlement') return null;
      final expires = DateTime.tryParse(m['expiresAt'] as String? ?? '');
      final productId = m['productId'];
      final platform = m['platform'];
      final status = m['status'];
      if (expires == null ||
          productId is! String ||
          platform is! String ||
          status is! String) {
        return null;
      }
      return AdFreeEntitlement(
        productId: productId,
        platform: platform,
        expiresAt: expires.toUtc(),
        status: status,
      );
    } on FormatException {
      return null;
    }
  }

  /// Verifies a signed entitlement envelope (same format/key as config).
  static Future<AdFreeEntitlement?> verify(
    ConfigVerifier verifier,
    String envelope,
  ) async {
    final payload = await verifier.verifyEnvelope(envelope);
    return payload == null ? null : fromPayload(payload);
  }
}
