import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/tabs_repository.dart';
import 'browser_tab.dart';

/// Picks tabs whose native WebViews should be released to bound memory:
/// least-recently-used first, never the current tab and never a tab that is
/// playing media.
List<BrowserTab> tabsToFreeze(
  List<BrowserTab> tabs, {
  required String? currentId,
  required int maxLive,
}) {
  final live = tabs.where((t) => t.hasLiveWebView).toList();
  final excess = live.length - maxLive;
  if (excess <= 0) return const [];
  final candidates = live
      .where((t) => t.id != currentId && !t.mediaPlaying)
      .toList()
    ..sort((a, b) => a.lastActive.compareTo(b.lastActive));
  return candidates.take(excess).toList();
}

/// Owns the list of open tabs (normal and private) and which one is shown.
class TabsController extends ChangeNotifier {
  TabsController({
    required TabsRepository? repository,
    DateTime Function()? clock,
    this.maxLiveWebViews = 5,
    this.onFreeze,
    this.onPrivateSessionEnded,
  })  : _repo = repository,
        _clock = clock ?? DateTime.now;

  final TabsRepository? _repo;
  final DateTime Function() _clock;
  final int maxLiveWebViews;

  /// Called for each tab whose WebView must be released.
  final void Function(BrowserTab tab)? onFreeze;

  /// Called after the last private tab was closed, with the closed tabs, so
  /// the platform layer can destroy the isolated private data store.
  final Future<void> Function(List<BrowserTab> closed)? onPrivateSessionEnded;

  final List<BrowserTab> _tabs = [];
  String? _currentId;
  Timer? _saveTimer;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  List<BrowserTab> get normalTabs =>
      _tabs.where((t) => !t.isPrivate).toList(growable: false);
  List<BrowserTab> get privateTabs =>
      _tabs.where((t) => t.isPrivate).toList(growable: false);

  BrowserTab? get current {
    for (final t in _tabs) {
      if (t.id == _currentId) return t;
    }
    return null;
  }

  BrowserTab? byId(String id) {
    for (final t in _tabs) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> restore() async {
    final repo = _repo;
    if (repo == null) return;
    final stored = await repo.load();
    for (final s in stored) {
      final uri = Uri.tryParse(s.url);
      if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        continue;
      }
      _tabs.add(BrowserTab(
        id: s.id,
        isPrivate: false,
        url: uri,
        title: s.title,
        lastActive: s.lastActive,
      )..frozen = true); // created lazily when first shown
      if (s.isCurrent) _currentId = s.id;
    }
    notifyListeners();
  }

  BrowserTab open({Uri? url, bool private = false, bool background = false}) {
    final tab = BrowserTab(
      id: const Uuid().v4(),
      isPrivate: private,
      url: url,
      lastActive: _clock(),
    )..pendingLoad = url;
    final cur = current;
    final insertAt = cur == null ? _tabs.length : _tabs.indexOf(cur) + 1;
    _tabs.insert(insertAt, tab);
    if (!background) _select(tab);
    _changed();
    return tab;
  }

  void select(String id) {
    final tab = byId(id);
    if (tab == null) return;
    _select(tab);
    _changed();
  }

  void _select(BrowserTab tab) {
    _currentId = tab.id;
    tab.lastActive = _clock();
    if (tab.frozen && tab.url != null) {
      tab
        ..frozen = false
        ..keepAlive = null
        ..controller = null
        ..pendingLoad = tab.url;
    }
    for (final t in tabsToFreeze(_tabs,
        currentId: _currentId, maxLive: maxLiveWebViews)) {
      onFreeze?.call(t);
      t
        ..frozen = true
        ..keepAlive = null
        ..controller = null;
    }
  }

  Future<void> close(String id) async {
    final tab = byId(id);
    if (tab == null) return;
    final index = _tabs.indexOf(tab);
    _tabs.removeAt(index);
    if (_currentId == id) {
      // Prefer a neighbour of the same kind (private/normal).
      final sameKind = _tabs.where((t) => t.isPrivate == tab.isPrivate).toList();
      final next = sameKind.isEmpty
          ? null
          : sameKind[(index - 1).clamp(0, sameKind.length - 1)];
      _currentId = null;
      if (next != null) _select(next);
    }
    if (tab.isPrivate && privateTabs.isEmpty) {
      await onPrivateSessionEnded?.call([tab]);
    }
    _changed();
  }

  Future<void> closeAll({required bool private}) async {
    final closing = _tabs.where((t) => t.isPrivate == private).toList();
    _tabs.removeWhere((t) => t.isPrivate == private);
    if (closing.any((t) => t.id == _currentId)) _currentId = null;
    if (private && closing.isNotEmpty) {
      await onPrivateSessionEnded?.call(closing);
    }
    _changed();
  }

  void reorder(int oldIndex, int newIndex, {required bool private}) {
    final group = _tabs.where((t) => t.isPrivate == private).toList();
    if (oldIndex < 0 || oldIndex >= group.length) return;
    final moved = group.removeAt(oldIndex);
    group.insert(newIndex.clamp(0, group.length), moved);
    final others = _tabs.where((t) => t.isPrivate != private).toList();
    _tabs
      ..clear()
      ..addAll(private ? [...others, ...group] : [...group, ...others]);
    _changed();
  }

  List<BrowserTab> search(String query, {required bool private}) {
    final q = query.trim().toLowerCase();
    return _tabs
        .where((t) => t.isPrivate == private)
        .where((t) =>
            q.isEmpty ||
            t.title.toLowerCase().contains(q) ||
            (t.url?.toString().toLowerCase().contains(q) ?? false))
        .toList();
  }

  /// Called by the WebView layer whenever a tab's URL/title/state changes.
  void updated(BrowserTab tab, {bool persist = false}) {
    if (persist && !tab.isPrivate) _scheduleSave();
    notifyListeners();
  }

  void _changed() {
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    if (_repo == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), saveNow);
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    final repo = _repo;
    if (repo == null) return;
    final normal = normalTabs.where((t) => t.url != null).toList();
    await repo.saveAll([
      for (final (i, t) in normal.indexed)
        StoredTab(
          id: t.id,
          url: t.url.toString(),
          title: t.title,
          position: i,
          lastActive: t.lastActive,
          isCurrent: t.id == _currentId,
        ),
    ]);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
