import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/version.dart';
import '../data/key_value_store.dart';
import 'config_verifier.dart';
import 'default_config.dart';
import 'remote_config.dart';

enum ConfigSource { builtIn, cached, remote }

class EffectiveConfig {
  const EffectiveConfig(this.config, this.source);
  final RemoteConfig config;
  final ConfigSource source;
}

/// Loads, verifies and caches the signed remote configuration. It never
/// throws to callers and never blocks browsing: on any failure the last
/// valid config (or the built-in default) stays in effect.
class ConfigService extends ChangeNotifier {
  ConfigService({
    required KeyValueStore store,
    required ConfigVerifier verifier,
    required String baseUrl,
    required String appVersion,
    required String platform,
    http.Client? client,
    DateTime Function()? clock,
    bool allowInsecure = false,
  })  : _store = store,
        _verifier = verifier,
        _baseUrl = baseUrl,
        _appVersion = appVersion,
        _platform = platform,
        _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now,
        _allowInsecure = allowInsecure;

  static const _kEnvelope = 'config.envelope';
  static const _kAcceptedVersion = 'config.acceptedVersion';
  static const _kLastFetch = 'config.lastFetchMs';
  static const minRefreshInterval = Duration(hours: 1);

  final KeyValueStore _store;
  final ConfigVerifier _verifier;
  final String _baseUrl;
  final String _appVersion;
  final String _platform;
  final http.Client _client;
  final DateTime Function() _clock;
  final bool _allowInsecure;

  EffectiveConfig _current =
      EffectiveConfig(buildDefaultConfig(), ConfigSource.builtIn);
  EffectiveConfig get current => _current;
  RemoteConfig get config => _current.config;

  String? lastError;

  String get appVersion => _appVersion;

  bool get remoteEnabled {
    if (!_verifier.isConfigured || _baseUrl.isEmpty) return false;
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null) return false;
    return uri.scheme == 'https' || (_allowInsecure && uri.scheme == 'http');
  }

  /// Restores the cached envelope (re-verified, never trusted blindly).
  Future<void> loadCached() async {
    final raw = _store.getString(_kEnvelope);
    if (raw == null) return;
    final cfg = await _accept(raw, enforceMonotonic: false);
    if (cfg != null) _set(EffectiveConfig(cfg, ConfigSource.cached));
  }

  /// Fetches a fresh config if enough time has passed (or [force]).
  Future<void> refresh({bool force = false}) async {
    if (!remoteEnabled) return;
    final last = _store.getInt(_kLastFetch);
    final now = _clock();
    if (!force &&
        last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)) <
            minRefreshInterval) {
      // Still re-evaluate expiry of what we have.
      _reevaluate();
      return;
    }
    try {
      final uri = Uri.parse(_baseUrl).replace(
        path: '/api/v1/config',
        queryParameters: {'platform': _platform, 'appVersion': _appVersion},
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      await _store.setInt(_kLastFetch, now.millisecondsSinceEpoch);
      if (res.statusCode != 200) {
        lastError = 'http ${res.statusCode}';
        _reevaluate();
        return;
      }
      if (res.bodyBytes.length > 512 * 1024) {
        lastError = 'config too large';
        return;
      }
      final body = utf8.decode(res.bodyBytes);
      final cfg = await _accept(body, enforceMonotonic: true);
      if (cfg == null) {
        _reevaluate();
        return;
      }
      await _store.setString(_kEnvelope, body);
      await _store.setInt(_kAcceptedVersion, cfg.configVersion);
      lastError = null;
      _set(EffectiveConfig(cfg, ConfigSource.remote));
    } on Exception catch (e) {
      lastError = e.runtimeType.toString();
      _reevaluate();
    }
  }

  void _reevaluate() {
    final c = _current;
    if (c.source != ConfigSource.builtIn && !_usable(c.config)) {
      _set(EffectiveConfig(buildDefaultConfig(), ConfigSource.builtIn));
    }
  }

  bool _usable(RemoteConfig cfg) =>
      _clock().toUtc().isBefore(cfg.expiresAt) &&
      versionInRange(_appVersion, cfg.minAppVersion, cfg.maxAppVersion);

  Future<RemoteConfig?> _accept(
    String envelope, {
    required bool enforceMonotonic,
  }) async {
    final payload = await _verifier.verifyEnvelope(envelope);
    if (payload == null) {
      lastError = 'signature';
      return null;
    }
    final RemoteConfig cfg;
    try {
      cfg = RemoteConfig.parse(jsonDecode(payload));
    } on ConfigFormatException catch (e) {
      lastError = e.message;
      return null;
    } on FormatException {
      lastError = 'json';
      return null;
    }
    final accepted = _store.getInt(_kAcceptedVersion) ?? 0;
    if (enforceMonotonic && cfg.configVersion < accepted) {
      lastError = 'rollback';
      return null;
    }
    if (!_usable(cfg)) {
      lastError = 'expired_or_incompatible';
      return null;
    }
    return cfg;
  }

  void _set(EffectiveConfig value) {
    _current = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
