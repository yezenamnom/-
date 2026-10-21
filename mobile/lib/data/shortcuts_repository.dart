import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../config/remote_config.dart';
import 'key_value_store.dart';

class ShortcutItem {
  const ShortcutItem({
    required this.id,
    required this.title,
    required this.url,
    this.iconKey,
    this.color,
    this.remoteId,
  });

  final String id;
  final String title;
  final String url;
  final String? iconKey;
  final String? color;

  /// Set when the shortcut originated from the admin-managed defaults.
  final String? remoteId;
}

class ShortcutsView {
  const ShortcutsView(this.items, this.suggestions);
  final List<ShortcutItem> items;

  /// New admin-provided defaults the user has not seen yet. Shown as an
  /// offer, never added silently once the user has customised the list.
  final List<RemoteShortcut> suggestions;
}

ShortcutItem fromRemote(RemoteShortcut s, String languageCode) => ShortcutItem(
      id: 'remote:${s.id}',
      title: localized(s.title, languageCode),
      url: s.url,
      iconKey: s.iconKey,
      color: s.color,
      remoteId: s.id,
    );

/// Pure merge of admin defaults with the user's customisation.
ShortcutsView computeShortcutsView({
  required List<RemoteShortcut> remote,
  required bool customized,
  required List<ShortcutItem> userItems,
  required Set<String> seenRemoteIds,
  required Set<String> dismissedRemoteIds,
  required String languageCode,
}) {
  if (!customized) {
    return ShortcutsView(
      [for (final r in remote) fromRemote(r, languageCode)],
      const [],
    );
  }
  final present = userItems.map((u) => u.remoteId).whereType<String>().toSet();
  final suggestions = [
    for (final r in remote)
      if (!present.contains(r.id) &&
          !seenRemoteIds.contains(r.id) &&
          !dismissedRemoteIds.contains(r.id))
        r,
  ];
  return ShortcutsView(userItems, suggestions);
}

class ShortcutsRepository {
  ShortcutsRepository(this._db, this._store);
  final Database _db;
  final KeyValueStore _store;

  static const _kCustomized = 'shortcuts.customized';
  static const _kSeen = 'shortcuts.seenRemote';
  static const _kDismissed = 'shortcuts.dismissedRemote';
  static const maxShortcuts = 40;

  bool get customized => _store.getBool(_kCustomized) ?? false;
  Set<String> get seenRemoteIds => _readSet(_kSeen);
  Set<String> get dismissedRemoteIds => _readSet(_kDismissed);

  Set<String> _readSet(String key) {
    final raw = _store.getString(key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } on Object {
      return {};
    }
  }

  Future<void> _writeSet(String key, Set<String> v) =>
      _store.setString(key, jsonEncode(v.toList()..sort()));

  Future<List<ShortcutItem>> loadUserItems() async {
    final rows = await _db.query('shortcuts', orderBy: 'position ASC');
    return [
      for (final r in rows)
        ShortcutItem(
          id: r['id'] as String,
          title: r['title'] as String,
          url: r['url'] as String,
          iconKey: r['icon_key'] as String?,
          color: r['color'] as String?,
          remoteId: r['remote_id'] as String?,
        ),
    ];
  }

  Future<void> _saveAll(List<ShortcutItem> items) async {
    await _db.transaction((txn) async {
      await txn.delete('shortcuts');
      for (final (i, s) in items.take(maxShortcuts).indexed) {
        await txn.insert('shortcuts', {
          'id': s.id,
          'title': s.title,
          'url': s.url,
          'icon_key': s.iconKey,
          'color': s.color,
          'position': i,
          'remote_id': s.remoteId,
        });
      }
    });
  }

  /// First user edit: snapshot what they currently see, then apply [edit].
  Future<void> edit(
    List<ShortcutItem> currentlyShown,
    List<RemoteShortcut> remote,
    List<ShortcutItem> Function(List<ShortcutItem>) editFn,
  ) async {
    final base = customized ? await loadUserItems() : currentlyShown;
    await _saveAll(editFn(List.of(base)));
    if (!customized) {
      await _store.setBool(_kCustomized, true);
      await _writeSet(_kSeen, remote.map((r) => r.id).toSet());
    }
  }

  Future<void> markSuggestionsSeen(Iterable<String> ids) async =>
      _writeSet(_kSeen, seenRemoteIds..addAll(ids));

  Future<void> dismissSuggestion(String id) async =>
      _writeSet(_kDismissed, dismissedRemoteIds..add(id));

  /// Back to admin defaults (explicit user action only).
  Future<void> resetToDefaults() async {
    await _db.delete('shortcuts');
    await _store.setBool(_kCustomized, false);
    await _store.remove(_kSeen);
    await _store.remove(_kDismissed);
  }

  static String newId() => 'user:${const Uuid().v4()}';
}
