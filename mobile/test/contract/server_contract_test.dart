// Contract test against a running admin server (not a mock).
// Skipped unless VELA_SERVER_URL and VELA_PUBLIC_KEY are set, e.g.:
//   VELA_SERVER_URL=http://localhost:3005 VELA_PUBLIC_KEY=<base64url> \
//     flutter test test/contract
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vela_browser/blocking/blocking_service.dart';
import 'package:vela_browser/config/config_service.dart';
import 'package:vela_browser/config/config_verifier.dart';
import 'package:vela_browser/data/blob_store.dart';
import 'package:vela_browser/data/key_value_store.dart';

void main() {
  final url = Platform.environment['VELA_SERVER_URL'] ?? '';
  final key = Platform.environment['VELA_PUBLIC_KEY'] ?? '';
  final skip = url.isEmpty || key.isEmpty
      ? 'set VELA_SERVER_URL and VELA_PUBLIC_KEY to run'
      : null;

  test('app accepts the server-signed config and its blocklist', () async {
    final store = MemoryStore();
    final config = ConfigService(
      store: store,
      verifier: ConfigVerifier.fromBase64Url(key),
      baseUrl: url,
      appVersion: '1.0.0',
      platform: 'android',
      allowInsecure: true,
    );
    await config.refresh(force: true);
    expect(config.lastError, isNull);
    expect(config.current.source, ConfigSource.remote);
    expect(config.config.configVersion, greaterThan(0));
    expect(config.config.shortcuts, isNotEmpty);

    final blocking = BlockingService(
      store: store,
      blobs: MemoryBlobStore(),
      loadBundled: () async =>
          File('assets/blocklists/starter.json').readAsBytesSync(),
      baseUrl: url,
    );
    await blocking.init();
    // Force a download even if the server list has the same version.
    final b = config.config.blocking;
    expect(b.listVersion, isNotNull);
    await blocking.applyConfig(b);
    expect(blocking.lastError, isNull);
    if (b.listVersion! > 1) {
      expect(blocking.source, BlocklistSource.downloaded);
    }
  }, skip: skip);

  test('wrong public key is rejected', () async {
    final config = ConfigService(
      store: MemoryStore(),
      verifier: ConfigVerifier.fromBase64Url(
          'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'),
      baseUrl: url,
      appVersion: '1.0.0',
      platform: 'ios',
      allowInsecure: true,
    );
    await config.refresh(force: true);
    expect(config.current.source, ConfigSource.builtIn);
    expect(config.lastError, 'signature');
  }, skip: skip);
}
