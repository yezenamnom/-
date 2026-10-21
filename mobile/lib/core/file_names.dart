import 'package:path/path.dart' as p;

const _maxNameLength = 120;

/// Extensions that are never auto-opened and get a `.download` suffix so the
/// OS will not treat them as executable/installable by double-tap.
const kDangerousExtensions = {
  'apk', 'aab', 'xapk', 'apks', 'exe', 'msi', 'bat', 'cmd', 'com', 'scr',
  'ps1', 'vbs', 'js', 'jar', 'sh', 'app', 'dmg', 'pkg', 'ipa', 'deb', 'rpm',
  'mobileconfig', 'html', 'htm', 'svg', 'xhtml',
};

/// Produces a safe file name for storing a download inside the app's
/// download directory: no path separators, no traversal, no control or
/// reserved characters, bounded length.
String sanitizeFileName(String? raw, {String fallback = 'download'}) {
  var name = (raw ?? '').trim();
  // Take only the last path segment of whatever the server sent.
  name = name.split(RegExp(r'[/\\]')).last;
  name = name.replaceAll(RegExp(r'[\x00-\x1f\x7f<>:"|?*\u202a-\u202e\u200e\u200f\u2066-\u2069]'), '_');
  name = name.replaceAll(RegExp(r'^\.+'), '');
  name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (name.isEmpty || name == '.' || name == '..') name = fallback;

  const reserved = {
    'con', 'prn', 'aux', 'nul', 'com1', 'com2', 'com3', 'com4', 'lpt1',
    'lpt2', 'lpt3',
  };
  if (reserved.contains(p.basenameWithoutExtension(name).toLowerCase())) {
    name = '_$name';
  }

  if (name.length > _maxNameLength) {
    final ext = p.extension(name);
    final keepExt = ext.length <= 10 ? ext : '';
    name = name.substring(0, _maxNameLength - keepExt.length) + keepExt;
  }

  final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
  if (kDangerousExtensions.contains(ext)) name = '$name.download';
  return name;
}

/// Parses a filename from a Content-Disposition header value.
String? fileNameFromContentDisposition(String? header) {
  if (header == null) return null;
  final star = RegExp(r"filename\*\s*=\s*(?:UTF-8|utf-8)''([^;]+)")
      .firstMatch(header);
  if (star != null) {
    try {
      return Uri.decodeComponent(star.group(1)!.trim());
    } catch (_) {}
  }
  final plain = RegExp(r'filename\s*=\s*"?([^";]+)"?').firstMatch(header);
  return plain?.group(1)?.trim();
}

/// Returns a name not present in [existing] by appending " (n)".
String uniqueFileName(String name, Set<String> existing) {
  if (!existing.contains(name)) return name;
  final base = p.basenameWithoutExtension(name);
  final ext = p.extension(name);
  for (var i = 1; i < 10000; i++) {
    final candidate = '$base ($i)$ext';
    if (!existing.contains(candidate)) return candidate;
  }
  return '${DateTime.now().millisecondsSinceEpoch}$ext';
}
