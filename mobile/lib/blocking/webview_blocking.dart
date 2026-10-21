import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'blocklist.dart';

const _resourceTypes = {
  'document': ContentBlockerTriggerResourceType.DOCUMENT,
  'image': ContentBlockerTriggerResourceType.IMAGE,
  'style-sheet': ContentBlockerTriggerResourceType.STYLE_SHEET,
  'script': ContentBlockerTriggerResourceType.SCRIPT,
  'font': ContentBlockerTriggerResourceType.FONT,
  'raw': ContentBlockerTriggerResourceType.RAW,
  'svg-document': ContentBlockerTriggerResourceType.SVG_DOCUMENT,
  'media': ContentBlockerTriggerResourceType.MEDIA,
};

/// Network rules as native content blockers (WKContentRuleList on iOS,
/// request interception inside flutter_inappwebview on Android). Cosmetic
/// rules are handled by [cosmeticUserScript] instead so both platforms
/// behave identically.
List<ContentBlocker> toContentBlockers(Blocklist list) => [
      for (final r in list.networkRules)
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: r.urlFilter,
            resourceType: [
              for (final t in r.resourceTypes) _resourceTypes[t]!,
            ],
          ),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
    ];

/// Document-start script that hides elements matching the list's cosmetic
/// selectors on the current page. All data is embedded with [jsonEncode]
/// (never string-concatenated), selectors were validated against a strict
/// character set, and the script exposes nothing to the page.
UserScript cosmeticUserScript(Blocklist list, Set<String> exceptions) {
  final generic = <String>[];
  final scoped = <List<Object>>[];
  for (final r in list.cosmeticRules) {
    if (r.ifDomain.isEmpty) {
      generic.add(r.selector!);
    } else {
      scoped.add([r.ifDomain, r.selector!]);
    }
  }
  final data = jsonEncode({
    'g': generic,
    's': scoped,
    'x': exceptions.toList(),
  });
  final source = '''
(function () {
  try {
    var d = $data;
    var h = (location.hostname || '').toLowerCase();
    if (!h) return;
    for (var i = 0; i < d.x.length; i++) {
      var e = d.x[i];
      if (h === e || h.slice(-(e.length + 1)) === '.' + e) return;
    }
    function m(p) {
      if (p.charAt(0) === '*') {
        var s = p.slice(1);
        return h === s.replace(/^\\./, '') || h.slice(-s.length) === s;
      }
      return h === p;
    }
    var sel = d.g.slice();
    for (var j = 0; j < d.s.length; j++) {
      if (d.s[j][0].some(m)) sel.push(d.s[j][1]);
    }
    if (!sel.length) return;
    var css = sel.join(',') + '{display:none !important;}';
    var st = document.createElement('style');
    st.textContent = css;
    (document.head || document.documentElement).appendChild(st);
  } catch (err) {}
})();
''';
  return UserScript(
    groupName: 'vela-cosmetic',
    source: source,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    forMainFrameOnly: true,
  );
}
