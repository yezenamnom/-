import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/remote_config.dart';
import '../data/blob_store.dart';
import '../data/key_value_store.dart';
import 'blocklist.dart';

enum BlocklistSource { bundled, downloaded }

/// Owns the active content-blocking list and the user's blocking choices.
///
/// Blocking applies only to pages inside this browser. The list is updated
/// from the signed config (version + SHA-256), the previous list is kept so
/// a faulty update can be reverted, and the bundled list is the last resort.
class BlockingService extends ChangeNotifier {
  BlockingService({
    required KeyValueStore store,
    required BlobStore blobs,
    required Future<List<int>> Function() loadBundled,
    required String baseUrl,
    http.Client? client,
  })  : _store = store,
        _blobs = blobs,
        _loadBundled = loadBundled,
        _baseUrl = baseUrl,
        _client = client ?? http.Client();

  static const _kEnabled = 'blocking.enabled';
  static const _kExceptions = 'blocking.exceptions';
  static const _kCurrent = 'blocklist-current.json';
  static const _kPrevious = 'blocklist-previous.json';

  final KeyValueStore _store;
  final BlobStore _blobs;
  final Future<List<int>> Function() _loadBundled;
  final String _baseUrl;
  final http.Client _client;

  late Blocklist _list;
  Blocklist get list => _list;
  BlocklistSource source = BlocklistSource.bundled;
  String? lastError;
  bool _enabledDefault = true;

  bool get enabled => _store.getBool(_kEnabled) ?? _enabledDefault;

  Set<String> get exceptions {
    final raw = _store.getString(_kExceptions);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } on Object {
      return {};
    }
  }

  bool isActiveFor(String host) =>
      enabled && host.isNotEmpty && !isHostExcepted(host, exceptions);

  Future<void> init() async {
    final cached = await _blobs.read(_kCurrent);
    if (cached != null) {
      try {
        _list = Blocklist.parseBytes(cached);
        source = BlocklistSource.downloaded;
        return;
      } on BlocklistFormatException {
        await _blobs.delete(_kCurrent);
      }
    }
    _list = Blocklist.parseBytes(await _loadBundled());
    source = BlocklistSource.bundled;
  }

  Future<void> setEnabled(bool value) async {
    await _store.setBool(_kEnabled, value);
    notifyListeners();
  }

  Future<void> setSiteException(String host, {required bool excepted}) async {
    final h = host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    if (h.isEmpty) return;
    final set = exceptions;
    excepted ? set.add(h) : set.remove(h);
    await _store.setString(_kExceptions, jsonEncode(set.toList()..sort()));
    notifyListeners();
  }

  /// Applies blocking settings from a verified remote config.
  Future<void> applyConfig(BlockingConfig cfg) async {
    _enabledDefault = cfg.enabledByDefault;
    final version = cfg.listVersion;
    if (version == null || version <= _list.version) {
      notifyListeners();
      return;
    }
    if (_baseUrl.isEmpty) return;
    try {
      final uri = Uri.parse(_baseUrl).replace(path: cfg.listPath);
      final res = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        lastError = 'http ${res.statusCode}';
        return;
      }
      final bytes = res.bodyBytes;
      if (sha256.convert(bytes).toString() != cfg.listSha256) {
        lastError = 'checksum';
        return;
      }
      final parsed = Blocklist.parseBytes(bytes);
      if (parsed.version != version) {
        lastError = 'version mismatch';
        return;
      }
      final current = await _blobs.read(_kCurrent);
      if (current != null) await _blobs.write(_kPrevious, current);
      await _blobs.write(_kCurrent, bytes);
      _list = parsed;
      source = BlocklistSource.downloaded;
      lastError = null;
      notifyListeners();
    } on BlocklistFormatException catch (e) {
      lastError = e.message;
    } on Exception catch (e) {
      lastError = e.runtimeType.toString();
    }
  }

  /// Reverts to the previously downloaded list, or to the bundled one.
  Future<void> revertToPrevious() async {
    final prev = await _blobs.read(_kPrevious);
    Blocklist? parsed;
    if (prev != null) {
      try {
        parsed = Blocklist.parseBytes(prev);
      } on BlocklistFormatException {
        parsed = null;
      }
    }
    if (parsed != null) {
      await _blobs.write(_kCurrent, prev!);
      await _blobs.delete(_kPrevious);
      _list = parsed;
      source = BlocklistSource.downloaded;
    } else {
      await _blobs.delete(_kCurrent);
      _list = Blocklist.parseBytes(await _loadBundled());
      source = BlocklistSource.bundled;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
