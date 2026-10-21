/// Search engines offered in settings. Names only; no third-party logos are
/// bundled (trademarks), see docs/LICENSE_AUDIT.md.
class SearchEngine {
  const SearchEngine({
    required this.id,
    required this.name,
    required this.searchTemplate,
  });

  final String id;
  final String name;

  /// Must contain `{q}`, replaced by the URL-encoded query.
  final String searchTemplate;

  Uri searchUri(String query) => Uri.parse(
        searchTemplate.replaceAll('{q}', Uri.encodeQueryComponent(query)),
      );
}

const kSearchEngines = <SearchEngine>[
  SearchEngine(
    id: 'duckduckgo',
    name: 'DuckDuckGo',
    searchTemplate: 'https://duckduckgo.com/?q={q}',
  ),
  SearchEngine(
    id: 'google',
    name: 'Google',
    searchTemplate: 'https://www.google.com/search?q={q}',
  ),
  SearchEngine(
    id: 'bing',
    name: 'Bing',
    searchTemplate: 'https://www.bing.com/search?q={q}',
  ),
  SearchEngine(
    id: 'brave',
    name: 'Brave Search',
    searchTemplate: 'https://search.brave.com/search?q={q}',
  ),
  SearchEngine(
    id: 'ecosia',
    name: 'Ecosia',
    searchTemplate: 'https://www.ecosia.org/search?q={q}',
  ),
  SearchEngine(
    id: 'startpage',
    name: 'Startpage',
    searchTemplate: 'https://www.startpage.com/do/search?q={q}',
  ),
];

const kDefaultSearchEngineId = 'duckduckgo';

SearchEngine searchEngineById(String? id) => kSearchEngines.firstWhere(
      (e) => e.id == id,
      orElse: () => kSearchEngines.firstWhere(
        (e) => e.id == kDefaultSearchEngineId,
      ),
    );
