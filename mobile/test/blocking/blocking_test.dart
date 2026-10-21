import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vela_browser/blocking/blocking_service.dart';
import 'package:vela_browser/blocking/blocklist.dart';
import 'package:vela_browser/blocking/webview_blocking.dart';
import 'package:vela_browser/config/remote_config.dart';
import 'package:vela_browser/data/blob_store.dart';
import 'package:vela_browser/data/key_value_store.dart';

Map<String, Object?> listJson(int version, List<Map<String, Object?>> rules) =>
    {
      'format': 'vela-blocklist',
      'formatVersion': 1,
      'version': version,
      'name': 'Test',
      'license': 'Original',
      'rules': rules,
    };

final blockAds = {
  'action': 'block',
  'urlFilter': r'^https?://([^/]+\.)?ads\.example\.net[/:]',
  'resourceTypes': <String>[],
};

void main() {
  final bundledBytes =
      File('assets/blocklists/starter.json').readAsBytesSync();

  test('bundled starter list is valid', () {
    final list = Blocklist.parseBytes(bundledBytes);
    expect(list.networkRules.length, greaterThan(30));
    expect(list.cosmeticRules, isNotEmpty);
    final blockers = toContentBlockers(list);
    expect(blockers.length, list.networkRules.length);
    final re = RegExp(list.networkRules
        .firstWhere((r) => r.urlFilter.contains('doubleclick'))
        .urlFilter);
    expect(re.hasMatch('https://securepubads.g.doubleclick.net/tag/js'), isTrue);
    expect(re.hasMatch('https://doubleclick.net/x'), isTrue);
    expect(re.hasMatch('https://notdoubleclick.net/x'), isFalse);
    expect(re.hasMatch('https://example.com/?ref=doubleclick.net'), isFalse);
  });

  group('validation', () {
    void bad(Map<String, Object?> rule) => expect(
        () => Blocklist.parse(listJson(1, [rule])),
        throwsA(isA<BlocklistFormatException>()),
        reason: rule.toString());

    test('rejects unsupported actions and regex', () {
      bad({'action': 'ignore-previous-rules', 'urlFilter': '.*'});
      bad({'action': 'block', 'urlFilter': 'a|b'});
      bad({'action': 'block', 'urlFilter': r'a{2}'});
      bad({'action': 'block', 'urlFilter': r'(?i)ads'});
      bad({'action': 'block', 'urlFilter': r'\d+'});
      bad({'action': 'block', 'urlFilter': ''});
      bad({'action': 'block', 'urlFilter': '(unclosed'});
      bad({
        'action': 'block',
        'urlFilter': '.*',
        'ifDomain': ['a.com']
      });
      bad({
        'action': 'block',
        'urlFilter': '.*',
        'resourceTypes': ['websocket']
      });
    });

    test('rejects selectors that could escape CSS or inject script', () {
      for (final s in [
        "a'); alert(1); ('",
        r'a\27',
        'a{}',
        'div</style><script>',
        '@import x',
        'a;b',
        'div[style*=url(x)]',
        'a/*x*/',
      ]) {
        bad({'action': 'css-display-none', 'urlFilter': '.*', 'selector': s});
      }
    });

    test('limits', () {
      expect(
          () => Blocklist.parse(listJson(1, List.filled(5001, blockAds))),
          throwsA(isA<BlocklistFormatException>()));
      expect(() => Blocklist.parseBytes(List.filled(1024 * 1024 + 1, 32)),
          throwsA(isA<BlocklistFormatException>()));
      expect(() => Blocklist.parse({'format': 'abp'}),
          throwsA(isA<BlocklistFormatException>()));
    });
  });

  test('cosmetic css respects page domains', () {
    final list = Blocklist.parse(listJson(1, [
      {'action': 'css-display-none', 'urlFilter': '.*', 'selector': '.g'},
      {
        'action': 'css-display-none',
        'urlFilter': '.*',
        'selector': '#only-a',
        'ifDomain': ['*a.com']
      },
    ]));
    expect(cosmeticCssFor(list, 'www.a.com'), contains('#only-a'));
    expect(cosmeticCssFor(list, 'b.com'), isNot(contains('#only-a')));
    expect(cosmeticCssFor(list, 'b.com'), contains('.g'));
    expect(domainMatches('a.com', '*.a.com'), isTrue);
    expect(domainMatches('evil-a.com', '*.a.com'), isFalse);
  });

  test('cosmetic script embeds data as JSON only', () {
    final list = Blocklist.parse(listJson(1, [
      {'action': 'css-display-none', 'urlFilter': '.*', 'selector': '.ad'},
    ]));
    final script = cosmeticUserScript(list, {'news.com'});
    expect(script.source, contains('"x":["news.com"]'));
    expect(script.source, contains('"g":[".ad"]'));
  });

  group('service', () {
    late MemoryStore store;
    late MemoryBlobStore blobs;
    setUp(() {
      store = MemoryStore();
      blobs = MemoryBlobStore();
    });

    BlockingService make(http.Client client) => BlockingService(
          store: store,
          blobs: blobs,
          loadBundled: () async => bundledBytes,
          baseUrl: 'https://config.example.com',
          client: client,
        );

    BlockingConfig cfg(int v, List<int> body, {String? sha}) => BlockingConfig(
          enabledByDefault: true,
          listVersion: v,
          listPath: '/api/v1/blocklists/$v',
          listSha256: sha ?? sha256.convert(body).toString(),
          ruleCount: 1,
        );

    test('updates only with matching checksum, keeps previous', () async {
      final v5 = utf8.encode(jsonEncode(listJson(5, [blockAds])));
      final s = make(MockClient((_) async => http.Response.bytes(v5, 200)));
      await s.init();
      expect(s.source, BlocklistSource.bundled);

      await s.applyConfig(cfg(5, v5, sha: '0' * 64));
      expect(s.list.version, 1);
      expect(s.lastError, 'checksum');

      await s.applyConfig(cfg(5, v5));
      expect(s.list.version, 5);
      expect(s.source, BlocklistSource.downloaded);

      final v6 = utf8.encode(jsonEncode(listJson(6, [blockAds, blockAds])));
      final s2 = make(MockClient((_) async => http.Response.bytes(v6, 200)));
      await s2.init();
      expect(s2.list.version, 5, reason: 'restored from cache');
      await s2.applyConfig(cfg(6, v6));
      expect(s2.list.version, 6);
      await s2.revertToPrevious();
      expect(s2.list.version, 5);
      await s2.revertToPrevious();
      expect(s2.source, BlocklistSource.bundled);
    });

    test('invalid downloaded list is rejected', () async {
      final badBody = utf8.encode(jsonEncode(listJson(9, [
        {'action': 'block', 'urlFilter': 'a|b'}
      ])));
      final s = make(MockClient((_) async => http.Response.bytes(badBody, 200)));
      await s.init();
      await s.applyConfig(cfg(9, badBody));
      expect(s.list.version, 1);
      expect(s.lastError, isNotNull);
    });

    test('global switch and per-site exceptions', () async {
      final s = make(MockClient((_) async => http.Response('', 404)));
      await s.init();
      expect(s.isActiveFor('news.com'), isTrue);
      await s.setSiteException('www.News.com', excepted: true);
      expect(s.exceptions, {'news.com'});
      expect(s.isActiveFor('m.news.com'), isFalse);
      expect(s.isActiveFor('othernews.com'), isTrue);
      await s.setSiteException('news.com', excepted: false);
      expect(s.isActiveFor('news.com'), isTrue);
      await s.setEnabled(false);
      expect(s.isActiveFor('a.com'), isFalse);
    });
  });
}
