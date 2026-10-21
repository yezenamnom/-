/// Classification of navigation targets. The browser only loads http(s) and
/// about:blank itself; everything else is either handed to the OS after the
/// user confirms, or refused.
enum UrlDisposition {
  /// Load inside the WebView.
  load,

  /// Hand to another app (mailto:, tel:, market:, intent:, app deep links)
  /// only after explicit user confirmation.
  external,

  /// Never load or hand off (javascript:, file:, data:, content:, blob: as
  /// top-level navigation from untrusted input, etc.).
  blocked,
}

const _webSchemes = {'http', 'https'};

/// Schemes that are always refused as a top-level navigation coming from a
/// page or typed by the user.
const _blockedSchemes = {
  'javascript',
  'file',
  'data',
  'content',
  'blob',
  'vbscript',
  'filesystem',
  'chrome',
  'chrome-extension',
  'view-source',
  'ws',
  'wss',
};

UrlDisposition classifyUrl(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (_webSchemes.contains(scheme)) {
    return uri.host.isEmpty ? UrlDisposition.blocked : UrlDisposition.load;
  }
  if (scheme == 'about') {
    return uri.path == 'blank' ? UrlDisposition.load : UrlDisposition.blocked;
  }
  if (scheme.isEmpty || _blockedSchemes.contains(scheme)) {
    return UrlDisposition.blocked;
  }
  // intent:// URIs can target arbitrary components; they are still only
  // offered externally after confirmation, never auto-launched.
  return UrlDisposition.external;
}

/// True for hosts that should never be the target of remote-config URLs
/// (loopback, private ranges, link-local, single-label names).
bool isPrivateOrLocalHost(String host) {
  final h = host.toLowerCase().trim();
  if (h.isEmpty) return true;
  if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local')) {
    return true;
  }
  if (h.startsWith('[') || h.contains(':')) {
    // IPv6 literal: refuse all for remote config purposes.
    return true;
  }
  final parts = h.split('.');
  final isIpv4 =
      parts.length == 4 && parts.every((p) => int.tryParse(p) != null);
  if (isIpv4) {
    final o = parts.map(int.parse).toList();
    if (o.any((x) => x < 0 || x > 255)) return true;
    return o[0] == 10 ||
        o[0] == 127 ||
        o[0] == 0 ||
        (o[0] == 169 && o[1] == 254) ||
        (o[0] == 172 && o[1] >= 16 && o[1] <= 31) ||
        (o[0] == 192 && o[1] == 168) ||
        (o[0] == 100 && o[1] >= 64 && o[1] <= 127) ||
        o[0] >= 224;
  }
  return !h.contains('.');
}

/// A public https URL suitable for links coming from remote config.
bool isSafeRemoteHttpsUrl(String? value) {
  if (value == null || value.length > 2048) return false;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return false;
  }
  return !isPrivateOrLocalHost(uri.host);
}

/// Host to show in the address bar. Punycode (xn--) is kept as-is so that
/// homograph domains are visible, and `www.` is trimmed for readability.
String displayHost(Uri uri) {
  final host = uri.host.toLowerCase();
  return host.startsWith('www.') ? host.substring(4) : host;
}
