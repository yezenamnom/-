import '../core/url_safety.dart';

/// Typed, validated view of the signed remote configuration
/// (docs/CONFIG_CONTRACT.md, schemaVersion 1). Parsing is strict: anything
/// outside the contract throws [ConfigFormatException] and the whole config
/// is rejected, so a malformed field can never be partially applied.
class ConfigFormatException implements Exception {
  ConfigFormatException(this.message);
  final String message;
  @override
  String toString() => 'ConfigFormatException: $message';
}

const kSupportedSchemaVersion = 1;
const kMaxShortcuts = 24;

const kAllowedIconKeys = {
  'youtube', 'twitch', 'tiktok', 'rumble', 'facebook', 'instagram', 'x',
  'reddit', 'vimeo', 'dailymotion', 'news', 'generic',
};

/// Placement ids the app knows how to render. Unknown ids are ignored, not
/// rejected, so a newer admin panel cannot break older apps.
enum AdPlacementId { homeBanner, downloadsBanner, tabsInterstitial }

const _placementKeys = {
  'home_banner': AdPlacementId.homeBanner,
  'downloads_banner': AdPlacementId.downloadsBanner,
  'tabs_interstitial': AdPlacementId.tabsInterstitial,
};

const _placementFormats = {
  AdPlacementId.homeBanner: 'banner',
  AdPlacementId.downloadsBanner: 'banner',
  AdPlacementId.tabsInterstitial: 'interstitial',
};

final _adUnitPattern = RegExp(r'^ca-app-pub-\d{16}/\d{10}$');
final _colorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');

typedef LocalizedText = Map<String, String>;

String localized(LocalizedText text, String languageCode) =>
    text[languageCode] ?? text['en'] ?? (text.isEmpty ? '' : text.values.first);

class RemoteShortcut {
  const RemoteShortcut({
    required this.id,
    required this.title,
    required this.url,
    required this.iconKey,
    required this.iconAssetId,
    required this.color,
    required this.order,
  });

  final String id;
  final LocalizedText title;
  final String url;
  final String? iconKey;
  final String? iconAssetId;
  final String? color;
  final int order;
}

class AdPlacementConfig {
  const AdPlacementConfig({
    required this.id,
    required this.enabled,
    required this.adUnitIdAndroid,
    required this.adUnitIdIos,
  });

  final AdPlacementId id;
  final bool enabled;
  final String? adUnitIdAndroid;
  final String? adUnitIdIos;
}

class AdFrequency {
  const AdFrequency({
    required this.interstitialMinIntervalSec,
    required this.interstitialMaxPerSession,
  });

  /// Hard safety floor/ceiling compiled into the app. Remote values are
  /// clamped into this range; the admin panel cannot exceed it.
  static const minIntervalFloorSec = 300;
  static const maxPerSessionCeiling = 3;

  final int interstitialMinIntervalSec;
  final int interstitialMaxPerSession;

  factory AdFrequency.clamped(int minInterval, int maxPerSession) =>
      AdFrequency(
        interstitialMinIntervalSec:
            minInterval < minIntervalFloorSec ? minIntervalFloorSec : minInterval,
        interstitialMaxPerSession: maxPerSession.clamp(0, maxPerSessionCeiling),
      );
}

class AdsConfig {
  const AdsConfig({
    required this.enabled,
    required this.placements,
    required this.frequency,
  });

  final bool enabled;
  final Map<AdPlacementId, AdPlacementConfig> placements;
  final AdFrequency frequency;
}

class BlockingConfig {
  const BlockingConfig({
    required this.enabledByDefault,
    required this.listVersion,
    required this.listPath,
    required this.listSha256,
    required this.ruleCount,
  });

  final bool enabledByDefault;
  final int? listVersion;
  final String? listPath;
  final String? listSha256;
  final int? ruleCount;
}

class ContentConfig {
  const ContentConfig({
    this.privacyUrl,
    this.termsUrl,
    this.supportUrl,
    this.helpText = const {},
  });

  final String? privacyUrl;
  final String? termsUrl;
  final String? supportUrl;
  final LocalizedText helpText;
}

class RemoteNotice {
  const RemoteNotice({
    required this.id,
    required this.severity,
    required this.message,
    this.minAppVersion,
    this.maxAppVersion,
  });

  final String id;
  final String severity;
  final LocalizedText message;
  final String? minAppVersion;
  final String? maxAppVersion;
}

class RemoteConfig {
  const RemoteConfig({
    required this.configVersion,
    required this.issuedAt,
    required this.expiresAt,
    required this.minAppVersion,
    required this.maxAppVersion,
    required this.shortcuts,
    required this.ads,
    required this.blocking,
    required this.content,
    required this.notices,
  });

  final int configVersion;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String? minAppVersion;
  final String? maxAppVersion;
  final List<RemoteShortcut> shortcuts;
  final AdsConfig ads;
  final BlockingConfig blocking;
  final ContentConfig content;
  final List<RemoteNotice> notices;

  static RemoteConfig parse(Object? json) {
    final m = _map(json, 'root');
    final schema = _int(m['schemaVersion'], 'schemaVersion');
    if (schema != kSupportedSchemaVersion) {
      throw ConfigFormatException('unsupported schemaVersion $schema');
    }
    final shortcutsJson = _list(m['shortcuts'], 'shortcuts');
    if (shortcutsJson.length > kMaxShortcuts) {
      throw ConfigFormatException('too many shortcuts');
    }
    final shortcuts = [
      for (final (i, s) in shortcutsJson.indexed) _parseShortcut(s, i),
    ]..sort((a, b) => a.order.compareTo(b.order));
    final ids = shortcuts.map((s) => s.id).toSet();
    if (ids.length != shortcuts.length) {
      throw ConfigFormatException('duplicate shortcut id');
    }

    return RemoteConfig(
      configVersion: _int(m['configVersion'], 'configVersion'),
      issuedAt: _date(m['issuedAt'], 'issuedAt'),
      expiresAt: _date(m['expiresAt'], 'expiresAt'),
      minAppVersion: _optVersion(m['minAppVersion'], 'minAppVersion'),
      maxAppVersion: _optVersion(m['maxAppVersion'], 'maxAppVersion'),
      shortcuts: shortcuts,
      ads: _parseAds(m['ads']),
      blocking: _parseBlocking(m['blocking']),
      content: _parseContent(m['content']),
      notices: [
        for (final n in _list(m['notices'] ?? const [], 'notices'))
          _parseNotice(n),
      ],
    );
  }
}

RemoteShortcut _parseShortcut(Object? json, int index) {
  final m = _map(json, 'shortcuts[$index]');
  final id = _str(m['id'], 'shortcut.id', max: 64);
  if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(id)) {
    throw ConfigFormatException('bad shortcut id');
  }
  final url = _str(m['url'], 'shortcut.url', max: 2048);
  if (!isSafeRemoteHttpsUrl(url)) {
    throw ConfigFormatException('shortcut url must be public https');
  }
  final iconKey = m['iconKey'];
  if (iconKey != null && !kAllowedIconKeys.contains(iconKey)) {
    throw ConfigFormatException('bad iconKey');
  }
  final iconAssetId = m['iconAssetId'];
  if (iconAssetId != null &&
      (iconAssetId is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(iconAssetId))) {
    throw ConfigFormatException('bad iconAssetId');
  }
  final color = m['color'];
  if (color != null && (color is! String || !_colorPattern.hasMatch(color))) {
    throw ConfigFormatException('bad color');
  }
  return RemoteShortcut(
    id: id,
    title: _localized(m['title'], 'shortcut.title', max: 40),
    url: url,
    iconKey: iconKey as String?,
    iconAssetId: iconAssetId as String?,
    color: color as String?,
    order: _int(m['order'], 'shortcut.order'),
  );
}

AdsConfig _parseAds(Object? json) {
  final m = _map(json, 'ads');
  final placements = <AdPlacementId, AdPlacementConfig>{};
  for (final p in _list(m['placements'], 'ads.placements')) {
    final pm = _map(p, 'placement');
    final id = _placementKeys[pm['id']];
    if (id == null) continue; // unknown placement from a newer panel
    if (pm['format'] != _placementFormats[id]) {
      throw ConfigFormatException('placement format mismatch');
    }
    String? unit(Object? v) {
      if (v == null || v == '') return null;
      if (v is! String || !_adUnitPattern.hasMatch(v)) {
        throw ConfigFormatException('bad ad unit id');
      }
      return v;
    }

    placements[id] = AdPlacementConfig(
      id: id,
      enabled: _bool(pm['enabled'], 'placement.enabled'),
      adUnitIdAndroid: unit(pm['adUnitIdAndroid']),
      adUnitIdIos: unit(pm['adUnitIdIos']),
    );
  }
  final f = _map(m['frequency'], 'ads.frequency');
  return AdsConfig(
    enabled: _bool(m['enabled'], 'ads.enabled'),
    placements: placements,
    frequency: AdFrequency.clamped(
      _int(f['interstitialMinIntervalSec'], 'interstitialMinIntervalSec'),
      _int(f['interstitialMaxPerSession'], 'interstitialMaxPerSession'),
    ),
  );
}

BlockingConfig _parseBlocking(Object? json) {
  final m = _map(json, 'blocking');
  final version = m['listVersion'];
  final path = m['listPath'];
  final sha = m['listSha256'];
  if (version != null) {
    if (version is! int || version < 1) {
      throw ConfigFormatException('bad listVersion');
    }
    if (path is! String ||
        !RegExp(r'^/api/v1/blocklists/\d+$').hasMatch(path)) {
      throw ConfigFormatException('bad listPath');
    }
    if (sha is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) {
      throw ConfigFormatException('bad listSha256');
    }
  }
  final count = m['ruleCount'];
  return BlockingConfig(
    enabledByDefault: _bool(m['enabledByDefault'], 'blocking.enabledByDefault'),
    listVersion: version as int?,
    listPath: path as String?,
    listSha256: sha as String?,
    ruleCount: count is int ? count : null,
  );
}

ContentConfig _parseContent(Object? json) {
  if (json == null) return const ContentConfig();
  final m = _map(json, 'content');
  String? url(Object? v, String name) {
    if (v == null || v == '') return null;
    if (v is! String || !isSafeRemoteHttpsUrl(v)) {
      throw ConfigFormatException('$name must be public https');
    }
    return v;
  }

  return ContentConfig(
    privacyUrl: url(m['privacyUrl'], 'privacyUrl'),
    termsUrl: url(m['termsUrl'], 'termsUrl'),
    supportUrl: url(m['supportUrl'], 'supportUrl'),
    helpText: m['helpText'] == null
        ? const {}
        : _localized(m['helpText'], 'helpText', max: 4000),
  );
}

RemoteNotice _parseNotice(Object? json) {
  final m = _map(json, 'notice');
  final severity = m['severity'];
  if (severity != 'info' && severity != 'update') {
    throw ConfigFormatException('bad notice severity');
  }
  return RemoteNotice(
    id: _str(m['id'], 'notice.id', max: 64),
    severity: severity as String,
    message: _localized(m['message'], 'notice.message', max: 280),
    minAppVersion: _optVersion(m['minAppVersion'], 'notice.minAppVersion'),
    maxAppVersion: _optVersion(m['maxAppVersion'], 'notice.maxAppVersion'),
  );
}

Map<String, Object?> _map(Object? v, String name) {
  if (v is Map) return v.cast<String, Object?>();
  throw ConfigFormatException('$name must be an object');
}

List<Object?> _list(Object? v, String name) {
  if (v is List) return v.cast<Object?>();
  throw ConfigFormatException('$name must be a list');
}

int _int(Object? v, String name) {
  if (v is int) return v;
  throw ConfigFormatException('$name must be an integer');
}

bool _bool(Object? v, String name) {
  if (v is bool) return v;
  throw ConfigFormatException('$name must be a boolean');
}

String _str(Object? v, String name, {required int max}) {
  if (v is String && v.isNotEmpty && v.length <= max) return v;
  throw ConfigFormatException('$name must be a string of 1..$max chars');
}

DateTime _date(Object? v, String name) {
  final d = v is String ? DateTime.tryParse(v) : null;
  if (d == null) throw ConfigFormatException('$name must be an ISO date');
  return d.toUtc();
}

String? _optVersion(Object? v, String name) {
  if (v == null) return null;
  if (v is String && RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v)) return v;
  throw ConfigFormatException('$name must be x.y.z');
}

LocalizedText _localized(Object? v, String name, {required int max}) {
  final m = _map(v, name);
  final out = <String, String>{};
  for (final e in m.entries) {
    if (!RegExp(r'^[a-z]{2}$').hasMatch(e.key)) continue;
    out[e.key] = _str(e.value, '$name.${e.key}', max: max);
  }
  if (!out.containsKey('en')) {
    throw ConfigFormatException('$name requires an "en" entry');
  }
  return out;
}
