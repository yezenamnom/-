import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/config_verifier.dart';
import '../data/key_value_store.dart';
import '../data/secret_store.dart';
import 'entitlement.dart';

enum SubscriptionAvailability {
  /// Product ids or the verification server are not configured in this
  /// build. Purchasing is hidden.
  notConfigured,

  /// Store not reachable / billing unavailable on this device.
  storeUnavailable,

  /// Products not found in the store (not created or not approved yet).
  productsMissing,
  ready,
}

/// Subscriptions that remove *this app's* ads (nothing else: it is not a
/// subscription to any video platform). Prices always come from the store.
class SubscriptionService extends ChangeNotifier {
  SubscriptionService({
    required KeyValueStore store,
    SecretStore? secrets,
    required ConfigVerifier verifier,
    required String baseUrl,
    required List<String> productIds,
    required String platform,
    InAppPurchase? iap,
    http.Client? client,
    DateTime Function()? clock,
  })  : _store = store,
        _secrets = secrets ?? MemorySecretStore(),
        _verifier = verifier,
        _baseUrl = baseUrl,
        _productIds = productIds.where((p) => p.isNotEmpty).toSet(),
        _platform = platform,
        _iap = iap,
        _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  static const _kEntitlement = 'billing.entitlement';
  static const _kLastVerification = 'billing.lastVerification';

  /// Re-verify with the server when the signed entitlement (max 7 days)
  /// is this close to expiry, so renewals, cancellations and refunds apply.
  static const refreshBefore = Duration(days: 2);

  final KeyValueStore _store;
  final SecretStore _secrets;
  final ConfigVerifier _verifier;
  final String _baseUrl;
  final Set<String> _productIds;
  final String _platform;
  final InAppPurchase? _iap;
  final http.Client _client;
  final DateTime Function() _clock;

  SubscriptionAvailability availability = SubscriptionAvailability.notConfigured;
  List<ProductDetails> products = const [];
  AdFreeEntitlement? _entitlement;
  String? lastError;
  bool busy = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool get isConfigured =>
      _productIds.isNotEmpty && _baseUrl.isNotEmpty && _verifier.isConfigured;

  bool get adFree => _entitlement?.isValidAt(_clock()) ?? false;
  AdFreeEntitlement? get entitlement => _entitlement;

  Future<void> init() async {
    final cached = _store.getString(_kEntitlement);
    if (cached != null) {
      _entitlement = await AdFreeEntitlement.verify(_verifier, cached);
    }
    await refreshEntitlementIfDue();
    final iap = _iap;
    if (!isConfigured || iap == null) {
      availability = SubscriptionAvailability.notConfigured;
      notifyListeners();
      return;
    }
    _sub = iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    if (!await iap.isAvailable()) {
      availability = SubscriptionAvailability.storeUnavailable;
      notifyListeners();
      return;
    }
    final res = await iap.queryProductDetails(_productIds);
    products = res.productDetails;
    availability = products.isEmpty
        ? SubscriptionAvailability.productsMissing
        : SubscriptionAvailability.ready;
    notifyListeners();
  }

  /// Re-sends the last verified purchase to the server when the
  /// entitlement is missing or about to expire. Silent; never throws.
  Future<void> refreshEntitlementIfDue() async {
    if (_baseUrl.isEmpty || !_verifier.isConfigured) return;
    final ent = _entitlement;
    if (ent != null &&
        ent.expiresAt.difference(_clock().toUtc()) > refreshBefore) {
      return;
    }
    final body = await _secrets.read(_kLastVerification);
    if (body == null) return;
    await _postVerification(body);
    notifyListeners();
  }

  Future<void> buy(ProductDetails product) async {
    final iap = _iap;
    if (iap == null || availability != SubscriptionAvailability.ready) return;
    busy = true;
    notifyListeners();
    await iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> restore() async {
    final iap = _iap;
    if (iap == null || !isConfigured) return;
    busy = true;
    notifyListeners();
    await iap.restorePurchases();
    busy = false;
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          lastError = p.error?.message;
          if (p.pendingCompletePurchase) await _iap!.completePurchase(p);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ok = await _verifyWithServer(p);
          // Only acknowledge after server verification; unacknowledged
          // Google Play purchases are refunded automatically.
          if (ok && p.pendingCompletePurchase) {
            await _iap!.completePurchase(p);
          }
      }
    }
    busy = false;
    notifyListeners();
  }

  Future<bool> _verifyWithServer(PurchaseDetails p) async {
    final body = jsonEncode({
      'platform': _platform,
      'productId': p.productID,
      'verificationData': p.verificationData.serverVerificationData,
      'source': p.verificationData.source,
    });
    final ok = await _postVerification(body);
    if (ok) await _secrets.write(_kLastVerification, body);
    return ok;
  }

  Future<bool> _postVerification(String body) async {
    try {
      final res = await _client
          .post(
            Uri.parse(_baseUrl).replace(path: '/api/v1/entitlements/verify'),
            headers: {'content-type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        lastError = res.statusCode == 501
            ? 'verification_not_configured'
            : 'verification_failed';
        if (res.statusCode == 400) {
          // The store rejected this purchase: forget it.
          await _secrets.delete(_kLastVerification);
        }
        return false;
      }
      final ent = await AdFreeEntitlement.verify(_verifier, res.body);
      if (ent == null) {
        lastError = 'invalid_entitlement';
        return false;
      }
      _entitlement = ent;
      await _store.setString(_kEntitlement, res.body);
      final valid = ent.isValidAt(_clock());
      if (!valid) await _secrets.delete(_kLastVerification);
      return valid;
    } on Exception {
      lastError = 'network';
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _client.close();
    super.dispose();
  }
}
