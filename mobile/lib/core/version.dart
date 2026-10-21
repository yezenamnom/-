/// Minimal semantic-version comparison for "1.2.3" style strings. Pre-release
/// or build suffixes (`-beta`, `+5`) are ignored.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split(RegExp(r'[-+]'))
      .first
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final pa = parse(a), pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

bool versionInRange(String version, String? min, String? max) {
  if (min != null && compareVersions(version, min) < 0) return false;
  if (max != null && compareVersions(version, max) > 0) return false;
  return true;
}
