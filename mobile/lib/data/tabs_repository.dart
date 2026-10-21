import 'package:sqflite/sqflite.dart';

class StoredTab {
  const StoredTab({
    required this.id,
    required this.url,
    required this.title,
    required this.position,
    required this.lastActive,
    required this.isCurrent,
  });

  final String id;
  final String url;
  final String title;
  final int position;
  final DateTime lastActive;
  final bool isCurrent;
}

/// Persists normal (non-private) tabs so they can be restored after a
/// restart. Private tabs are never passed to this repository.
class TabsRepository {
  TabsRepository(this._db);
  final Database _db;

  Future<List<StoredTab>> load() async {
    final rows = await _db.query('tabs', orderBy: 'position ASC');
    return [
      for (final r in rows)
        StoredTab(
          id: r['id'] as String,
          url: r['url'] as String,
          title: r['title'] as String,
          position: r['position'] as int,
          lastActive:
              DateTime.fromMillisecondsSinceEpoch(r['last_active'] as int),
          isCurrent: (r['is_current'] as int) == 1,
        ),
    ];
  }

  /// Replaces the whole stored set atomically.
  Future<void> saveAll(List<StoredTab> tabs) => _db.transaction((txn) async {
        await txn.delete('tabs');
        for (final t in tabs) {
          await txn.insert('tabs', {
            'id': t.id,
            'url': t.url,
            'title': t.title,
            'position': t.position,
            'last_active': t.lastActive.millisecondsSinceEpoch,
            'is_current': t.isCurrent ? 1 : 0,
          });
        }
      });
}
