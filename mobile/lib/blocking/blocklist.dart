import 'dart:convert';

/// Declarative content-blocking list (docs/CONFIG_CONTRACT.md, format
/// "vela-blocklist" v1). Only data: no scripts, no free-form CSS.
class BlocklistFormatException implements Exception {
  BlocklistFormatException(this.message);
  final String message;
  @override
  String toString() => 'BlocklistFormatException: $message';
}

const kMaxBlocklistRules = 5000;
const kMaxBlocklistBytes = 1024 * 1024;

const kAllowedResourceTypes = {
  'document', 'image', 'style-sheet', 'script', 'font', 'raw',
  'svg-document', 'media',
};

final _forbiddenRegex = RegExp(r'[|{}]|\(\?|\\[dwsbDWSB]');
final _selectorChars = RegExp(r'^[A-Za-z0-9 .#_\-\[\]=^$*~:(),>+"]+$');
final _domainPattern = RegExp(r'^\*?[a-z0-9.-]+$');

enum BlockAction { block, cssDisplayNone }

class BlockRule {
  const BlockRule.block({
    required this.urlFilter,
    this.resourceTypes = const [],
  })  : action = BlockAction.block,
        selector = null,
        ifDomain = const [];

  const BlockRule.hide({required this.selector, this.ifDomain = const []})
      : action = BlockAction.cssDisplayNone,
        urlFilter = '.*',
        resourceTypes = const [];

  final BlockAction action;
  final String urlFilter;
  final List<String> resourceTypes;
  final String? selector;

  /// Page domains for cosmetic rules; empty = all pages.
  final List<String> ifDomain;
}

class Blocklist {
  const Blocklist({
    required this.version,
    required this.name,
    required this.license,
    required this.rules,
  });

  final int version;
  final String name;
  final String license;
  final List<BlockRule> rules;

  Iterable<BlockRule> get networkRules =>
      rules.where((r) => r.action == BlockAction.block);
  Iterable<BlockRule> get cosmeticRules =>
      rules.where((r) => r.action == BlockAction.cssDisplayNone);

  static Blocklist parseBytes(List<int> bytes) {
    if (bytes.length > kMaxBlocklistBytes) {
      throw BlocklistFormatException('list too large');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw BlocklistFormatException('invalid json');
    }
    return parse(json);
  }

  static Blocklist parse(Object? json) {
    if (json is! Map) throw BlocklistFormatException('root must be object');
    if (json['format'] != 'vela-blocklist' || json['formatVersion'] != 1) {
      throw BlocklistFormatException('unsupported format');
    }
    final version = json['version'];
    if (version is! int || version < 1) {
      throw BlocklistFormatException('bad version');
    }
    final rawRules = json['rules'];
    if (rawRules is! List) throw BlocklistFormatException('rules missing');
    if (rawRules.length > kMaxBlocklistRules) {
      throw BlocklistFormatException('too many rules');
    }
    return Blocklist(
      version: version,
      name: _string(json['name'], 'name', 200),
      license: _string(json['license'], 'license', 500),
      rules: [for (final r in rawRules) _parseRule(r)],
    );
  }
}

BlockRule _parseRule(Object? raw) {
  if (raw is! Map) throw BlocklistFormatException('rule must be object');
  List<String> strings(Object? v, String name) {
    if (v == null) return const [];
    if (v is! List || v.any((e) => e is! String)) {
      throw BlocklistFormatException('$name must be string list');
    }
    return v.cast<String>();
  }

  switch (raw['action']) {
    case 'block':
      final filter = validateUrlFilter(raw['urlFilter']);
      if (strings(raw['ifDomain'], 'ifDomain').isNotEmpty ||
          strings(raw['unlessDomain'], 'unlessDomain').isNotEmpty) {
        throw BlocklistFormatException('block rules cannot be domain-scoped');
      }
      final types = strings(raw['resourceTypes'], 'resourceTypes');
      if (types.any((t) => !kAllowedResourceTypes.contains(t))) {
        throw BlocklistFormatException('bad resource type');
      }
      return BlockRule.block(urlFilter: filter, resourceTypes: types);
    case 'css-display-none':
      final selector = validateSelector(raw['selector']);
      final domains = strings(raw['ifDomain'], 'ifDomain');
      if (domains.length > 200 ||
          domains.any((d) => d.length > 253 || !_domainPattern.hasMatch(d))) {
        throw BlocklistFormatException('bad ifDomain');
      }
      return BlockRule.hide(selector: selector, ifDomain: domains);
    default:
      throw BlocklistFormatException('unsupported action');
  }
}

String validateUrlFilter(Object? v) {
  if (v is! String || v.isEmpty || v.length > 512) {
    throw BlocklistFormatException('bad urlFilter length');
  }
  if (_forbiddenRegex.hasMatch(v)) {
    throw BlocklistFormatException('urlFilter uses unsupported regex syntax');
  }
  try {
    RegExp(v);
  } on FormatException {
    throw BlocklistFormatException('urlFilter is not a valid regex');
  }
  return v;
}

String validateSelector(Object? v) {
  if (v is! String || v.trim().isEmpty || v.length > 1000) {
    throw BlocklistFormatException('bad selector length');
  }
  final lower = v.toLowerCase();
  if (!_selectorChars.hasMatch(v) ||
      lower.contains('url(') ||
      lower.contains('expression(')) {
    throw BlocklistFormatException('selector contains forbidden characters');
  }
  return v;
}

String _string(Object? v, String name, int max) {
  if (v is String && v.isNotEmpty && v.length <= max) return v;
  throw BlocklistFormatException('bad $name');
}

/// True when [host] matches a rule domain: exact, or "*suffix" style.
bool domainMatches(String host, String pattern) {
  final h = host.toLowerCase();
  if (pattern.startsWith('*')) {
    final suffix = pattern.substring(1);
    return h == suffix.replaceFirst(RegExp(r'^\.'), '') || h.endsWith(suffix);
  }
  return h == pattern;
}

/// User per-site exceptions: blocking is off for [host] if it equals or is a
/// subdomain of any excepted site.
bool isHostExcepted(String host, Iterable<String> exceptions) {
  final h = host.toLowerCase();
  return exceptions.any((e) => h == e || h.endsWith('.$e'));
}

/// Builds the cosmetic stylesheet for a page host. Selectors were validated
/// against a strict character set, so the result is plain CSS.
String cosmeticCssFor(Blocklist list, String host) {
  final selectors = <String>[
    for (final r in list.cosmeticRules)
      if (r.ifDomain.isEmpty || r.ifDomain.any((d) => domainMatches(host, d)))
        r.selector!,
  ];
  if (selectors.isEmpty) return '';
  return '${selectors.join(',\n')} { display: none !important; }';
}
