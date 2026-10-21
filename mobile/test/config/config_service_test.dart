import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vela_browser/config/config_service.dart';
import 'package:vela_browser/config/config_verifier.dart';
import 'package:vela_browser/config/remote_config.dart';
import 'package:vela_browser/data/key_value_store.dart';

Map<String, Object?> validPayload({
  int version = 5,
  DateTime? expires,
  String? minApp,
  Map<String, Object?>? overrides,
}) {
  final now = DateTime.utc(2026, 10, 21, 12);
  return {
    'schemaVersion': 1,
    'configVersion': version,
    'issuedAt': now.toIso8601String(),
    'expiresAt': (expires ?? now.add(const Duration(days: 7))).toIso8601String(),
    'minAppVersion': minApp,
    'maxAppVersion': null,
    'shortcuts': [
      {
        'id': 'youtube',
        'title': {'en': 'YouTube', 'ar': 'يوتيوب'},
        'url': 'https://m.youtube.com/',
        'iconKey': 'youtube',
        'iconAssetId': null,
        'color': '#E53935',
        'order': 1,
      },
      {
        'id': 'news',
        'title': {'en': 'News'},
        'url': 'https://news.example.com/',
        'iconKey': 'news',
        'iconAssetId': null,
        'color': null,
        'order': 0,
      },
    ],
    'ads': {
      'enabled': true,
      'placements': [
        {
          'id': 'home_banner',
          'format': 'banner',
          'enabled': true,
          'adUnitIdAndroid': 'ca-app-pub-3940256099942544/9214589741',
          'adUnitIdIos': 'ca-app-pub-3940256099942544/2435281174',
        },
        {
          'id': 'future_placement',
          'format': 'native',
          'enabled': true,
          'adUnitIdAndroid': null,
          'adUnitIdIos': null,
        },
      ],
      'frequency': {
        'interstitialMinIntervalSec': 10,
        'interstitialMaxPerSession': 50,
      },
    },
    'blocking': {
      'enabledByDefault': true,
      'listVersion': 3,
      'listPath': '/api/v1/blocklists/3',
      'listSha256': 'a' * 64,
      'ruleCount': 10,
    },
    'content': {
      'privacyUrl': 'https://example.com/privacy',
      'termsUrl': null,
      'supportUrl': null,
      'helpText': {'en': 'Help'},
    },
    'notices': [],
    ...?overrides,
  };
}

void main() {
  late SimpleKeyPair keyPair;
  late ConfigVerifier verifier;
  final clock = DateTime.utc(2026, 10, 22);

  setUpAll(() async {
    keyPair = await Ed25519().newKeyPair();
    final pub = await keyPair.extractPublicKey();
    verifier = ConfigVerifier.fromBase64Url(base64Url.encode(pub.bytes));
  });

  Future<String> sign(Map<String, Object?> payload, {SimpleKeyPair? key}) async {
    final bytes = utf8.encode(jsonEncode(payload));
    final sig = await Ed25519().sign(bytes, keyPair: key ?? keyPair);
    return jsonEncode({
      'keyId': 'k1',
      'payload': base64Url.encode(bytes),
      'signature': base64Url.encode(sig.bytes),
    });
  }

  ConfigService service(MemoryStore store, http.Client client,
          {String appVersion = '1.0.0'}) =>
      ConfigService(
        store: store,
        verifier: verifier,
        baseUrl: 'https://config.example.com',
        appVersion: appVersion,
        platform: 'android',
        client: client,
        clock: () => clock,
      );

  test('parse validates and clamps', () {
    final cfg = RemoteConfig.parse(validPayload());
    expect(cfg.shortcuts.first.id, 'news', reason: 'sorted by order');
    expect(cfg.ads.placements.length, 1, reason: 'unknown placement ignored');
    expect(cfg.ads.frequency.interstitialMinIntervalSec, 300);
    expect(cfg.ads.frequency.interstitialMaxPerSession, 3);
  });

  test('parse rejects unsafe values', () {
    void bad(Map<String, Object?> overrides) => expect(
        () => RemoteConfig.parse(validPayload(overrides: overrides)),
        throwsA(isA<ConfigFormatException>()),
        reason: overrides.toString());

    bad({
      'shortcuts': [
        {
          'id': 'x',
          'title': {'en': 'X'},
          'url': 'http://insecure.example.com',
          'order': 0,
        }
      ]
    });
    bad({
      'shortcuts': [
        {
          'id': 'x',
          'title': {'en': 'X'},
          'url': 'https://192.168.0.1/',
          'order': 0,
        }
      ]
    });
    bad({
      'shortcuts': [
        {
          'id': 'x',
          'title': {'en': 'X'},
          'url': 'javascript:alert(1)',
          'order': 0,
        }
      ]
    });
    bad({
      'shortcuts': [
        {
          'id': 'x',
          'title': {'ar': 'بدون إنجليزي'},
          'url': 'https://a.com',
          'order': 0,
        }
      ]
    });
    bad({'schemaVersion': 2});
    bad({
      'ads': {
        'enabled': true,
        'placements': [
          {
            'id': 'home_banner',
            'format': 'banner',
            'enabled': true,
            'adUnitIdAndroid': 'not-an-id',
          }
        ],
        'frequency': {
          'interstitialMinIntervalSec': 600,
          'interstitialMaxPerSession': 1
        },
      }
    });
    bad({
      'ads': {
        'enabled': true,
        'placements': [
          {'id': 'home_banner', 'format': 'interstitial', 'enabled': true}
        ],
        'frequency': {
          'interstitialMinIntervalSec': 600,
          'interstitialMaxPerSession': 1
        },
      }
    });
    bad({
      'content': {'privacyUrl': 'http://example.com'}
    });
  });

  test('accepts a correctly signed config and caches it', () async {
    final store = MemoryStore();
    final body = await sign(validPayload());
    final s = service(store, MockClient((_) async => http.Response(body, 200)));
    await s.refresh(force: true);
    expect(s.current.source, ConfigSource.remote);
    expect(s.config.configVersion, 5);

    final s2 = service(store, MockClient((_) async => http.Response('', 500)));
    await s2.loadCached();
    expect(s2.current.source, ConfigSource.cached);
    expect(s2.config.configVersion, 5);
  });

  test('rejects tampered payload and wrong key', () async {
    final store = MemoryStore();
    final env = jsonDecode(await sign(validPayload())) as Map<String, Object?>;
    final tampered = utf8.encode(jsonEncode(validPayload(version: 99)));
    env['payload'] = base64Url.encode(tampered);
    final s = service(store,
        MockClient((_) async => http.Response(jsonEncode(env), 200)));
    await s.refresh(force: true);
    expect(s.current.source, ConfigSource.builtIn);
    expect(s.lastError, 'signature');

    final other = await Ed25519().newKeyPair();
    final s2 = service(
        store,
        MockClient((_) async =>
            http.Response(await sign(validPayload(), key: other), 200)));
    await s2.refresh(force: true);
    expect(s2.current.source, ConfigSource.builtIn);
  });

  test('refuses version rollback', () async {
    final store = MemoryStore();
    var body = await sign(validPayload(version: 7));
    final s = service(store, MockClient((_) async => http.Response(body, 200)));
    await s.refresh(force: true);
    expect(s.config.configVersion, 7);
    body = await sign(validPayload(version: 6));
    await s.refresh(force: true);
    expect(s.config.configVersion, 7);
    expect(s.lastError, 'rollback');
  });

  test('expired or incompatible config falls back to built-in', () async {
    final store = MemoryStore();
    final s = service(
        store,
        MockClient((_) async => http.Response(
            await sign(validPayload(expires: DateTime.utc(2026, 10, 1))),
            200)));
    await s.refresh(force: true);
    expect(s.current.source, ConfigSource.builtIn);

    final s2 = service(
        store,
        MockClient((_) async =>
            http.Response(await sign(validPayload(minApp: '2.0.0')), 200)));
    await s2.refresh(force: true);
    expect(s2.current.source, ConfigSource.builtIn);
  });

  test('server down keeps browsing config and does not throw', () async {
    final s = service(MemoryStore(),
        MockClient((_) async => throw http.ClientException('offline')));
    await s.refresh(force: true);
    expect(s.current.source, ConfigSource.builtIn);
    expect(s.config.shortcuts, isNotEmpty);
  });

  test('remote disabled without key or https', () {
    final s = ConfigService(
      store: MemoryStore(),
      verifier: ConfigVerifier.fromBase64Url(''),
      baseUrl: 'https://x.com',
      appVersion: '1.0.0',
      platform: 'ios',
    );
    expect(s.remoteEnabled, isFalse);
    final s2 = ConfigService(
      store: MemoryStore(),
      verifier: verifier,
      baseUrl: 'http://x.com',
      appVersion: '1.0.0',
      platform: 'ios',
    );
    expect(s2.remoteEnabled, isFalse);
  });
}
