import 'search_engines.dart';
import 'url_safety.dart';

sealed class InputResolution {
  const InputResolution();
}

class NavigateTo extends InputResolution {
  const NavigateTo(this.uri);
  final Uri uri;
}

class SearchFor extends InputResolution {
  const SearchFor(this.query, this.uri);
  final String query;
  final Uri uri;
}

/// The user typed something with a non-web scheme (mailto:, tel:, ...).
/// The UI asks before handing it to another app.
class ExternalTarget extends InputResolution {
  const ExternalTarget(this.uri);
  final Uri uri;
}

final _hostLike = RegExp(
  r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+(?:[a-z]{2,63}|xn--[a-z0-9-]{1,59})$',
  caseSensitive: false,
);
final _ipv4 = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
final _schemePrefix = RegExp(r'^([a-z][a-z0-9+.-]*):', caseSensitive: false);

/// Decides whether [raw] is a URL or a search query. Never returns a
/// `javascript:`/`data:`/`file:` navigation: those are treated as search
/// text so typing them can't execute anything.
InputResolution? resolveInput(String raw, SearchEngine engine) {
  final input = raw.trim();
  if (input.isEmpty) return null;

  SearchFor search() => SearchFor(input, engine.searchUri(input));

  if (input.contains(RegExp(r'\s'))) return search();

  final schemeMatch = _schemePrefix.firstMatch(input);
  if (schemeMatch != null) {
    final scheme = schemeMatch.group(1)!.toLowerCase();
    // "localhost:8080" / "example.com:8443/x" look like scheme:... too.
    final looksLikeHostPort =
        RegExp(r'^[^/:]+:\d{1,5}(?:[/?#].*)?$').hasMatch(input);
    // "user:pass@host" is credential-style, not a scheme; never navigate it.
    final looksLikeCredentials = scheme != 'mailto' &&
        RegExp(r'^[^/:]+:[^/]*@').hasMatch(input);
    if (looksLikeCredentials) return search();
    if (!looksLikeHostPort) {
      final uri = Uri.tryParse(input);
      if (uri == null) return search();
      switch (classifyUrl(uri)) {
        case UrlDisposition.load:
          return NavigateTo(uri);
        case UrlDisposition.external:
          return scheme == 'http' || scheme == 'https'
              ? search()
              : ExternalTarget(uri);
        case UrlDisposition.blocked:
          return search();
      }
    }
  }

  final candidate = Uri.tryParse('https://$input');
  if (candidate == null || candidate.host.isEmpty) return search();
  final host = candidate.host;
  final isLocalhost = host == 'localhost';
  final isIp = _ipv4.hasMatch(host) &&
      host.split('.').every((p) => int.parse(p) <= 255);
  if (!(isLocalhost || isIp || _hostLike.hasMatch(host))) return search();
  if (candidate.userInfo.isNotEmpty) return search();

  // Local addresses rarely have certificates; respect an explicit scheme
  // otherwise, but default plain hosts to https.
  final uri = (isLocalhost || isIp)
      ? Uri.parse('http://$input')
      : candidate;
  return NavigateTo(uri);
}
