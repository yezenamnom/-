import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vela_browser/billing/entitlement.dart';
import 'package:vela_browser/billing/subscription_service.dart';
import 'package:vela_browser/config/config_verifier.dart';
import 'package:vela_browser/data/key_value_store.dart';
import 'package:vela_browser/data/secret_store.dart';

void main() {
  late SimpleKeyPair key;
  late ConfigVerifier verifier;
  final now = DateTime.utc(2026, 10, 21, 12);

  setUpAll(() async {
    key = await Ed25519().newKeyPair();
    verifier = ConfigVerifier.fromBase64Url(
        base64Url.encode((await key.extractPublicKey()).bytes));
  });

  Future<String> signed(Map<String, Object?> payload, {SimpleKeyPair? k}) async {
    final bytes = utf8.encode(jsonEncode(payload));
    final sig = await Ed25519().sign(bytes, keyPair: k ?? key);
    return jsonEncode({
      'keyId': 'k1',
      'payload': base64Url.encode(bytes),
      'signature': base64Url.encode(sig.bytes),
    });
  }

  Map<String, Object?> ent(String status, DateTime expires) => {
        'type': 'ad_free_entitlement',
        'platform': 'android',
        'productId': 'remove_ads_monthly',
        'status': status,
        'issuedAt': now.toIso8601String(),
        'expiresAt': expires.toIso8601String(),
      };

  test('entitlement must be signed by our key and unexpired', () async {
    final good = await AdFreeEntitlement.verify(
        verifier, await signed(ent('active', now.add(const Duration(days: 3)))));
    expect(good!.isValidAt(now), isTrue);
    expect(good.isValidAt(now.add(const Duration(days: 4))), isFalse);

    final forged = await AdFreeEntitlement.verify(verifier,
        await signed(ent('active', DateTime.utc(2099)), k: await Ed25519().newKeyPair()));
    expect(forged, isNull);

    final revoked = await AdFreeEntitlement.verify(
        verifier, await signed(ent('revoked', DateTime.utc(2099))));
    expect(revoked!.isValidAt(now), isFalse);

    expect(AdFreeEntitlement.fromPayload('{"adFree":true}'), isNull,
        reason: 'a bare client boolean is never accepted');
  });

  test('not configured: no ad-free, purchase hidden', () async {
    final s = SubscriptionService(
      store: MemoryStore(),
      verifier: verifier,
      baseUrl: '',
      productIds: const ['remove_ads_monthly'],
      platform: 'android',
    );
    await s.init();
    expect(s.isConfigured, isFalse);
    expect(s.availability, SubscriptionAvailability.notConfigured);
    expect(s.adFree, isFalse);
  });

  test('re-verifies stored purchase before the 7-day entitlement lapses',
      () async {
    final store = MemoryStore();
    final secrets = MemorySecretStore()
      ..values['billing.lastVerification'] = jsonEncode({
        'platform': 'android',
        'productId': 'remove_ads_monthly',
        'verificationData': 'token-abcdefghij',
      });
    // Cached entitlement expires in 1 day -> due for refresh.
    store.values['billing.entitlement'] =
        await signed(ent('active', now.add(const Duration(days: 1))));
    var calls = 0;
    final renewed = await signed(ent('active', now.add(const Duration(days: 7))));
    final s = SubscriptionService(
      store: store,
      secrets: secrets,
      verifier: verifier,
      baseUrl: 'https://config.example.com',
      productIds: const ['remove_ads_monthly'],
      platform: 'android',
      clock: () => now,
      client: MockClient((req) async {
        calls++;
        expect(req.url.path, '/api/v1/entitlements/verify');
        expect(jsonDecode(req.body)['verificationData'], 'token-abcdefghij');
        return http.Response(renewed, 200);
      }),
    );
    await s.init();
    expect(calls, 1);
    expect(s.adFree, isTrue);
    expect(s.entitlement!.expiresAt, now.add(const Duration(days: 7)));
  });

  test('store rejection or cancellation removes ad-free and the token',
      () async {
    final store = MemoryStore();
    final secrets = MemorySecretStore()
      ..values['billing.lastVerification'] = '{"platform":"android"}';
    final s = SubscriptionService(
      store: store,
      secrets: secrets,
      verifier: verifier,
      baseUrl: 'https://config.example.com',
      productIds: const ['remove_ads_monthly'],
      platform: 'android',
      clock: () => now,
      client: MockClient((_) async =>
          http.Response('{"error":"invalid_purchase"}', 400)),
    );
    await s.init();
    expect(s.adFree, isFalse);
    expect(secrets.values.containsKey('billing.lastVerification'), isFalse);
  });

  test('server without store credentials (501) keeps ads', () async {
    final secrets = MemorySecretStore()
      ..values['billing.lastVerification'] = '{"platform":"ios"}';
    final s = SubscriptionService(
      store: MemoryStore(),
      secrets: secrets,
      verifier: verifier,
      baseUrl: 'https://config.example.com',
      productIds: const ['remove_ads_monthly'],
      platform: 'ios',
      clock: () => now,
      client: MockClient(
          (_) async => http.Response('{"error":"not_configured"}', 501)),
    );
    await s.init();
    expect(s.adFree, isFalse);
    expect(s.lastError, 'verification_not_configured');
    expect(secrets.values, isNotEmpty, reason: 'retry once configured');
  });
}
