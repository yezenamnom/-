import 'package:sqflite/sqflite.dart';

import 'sql_utils.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.host,
    required this.visitedAt,
  });

  final int id;
  final String url;
  final String title;
  final String host;
  final DateTime visitedAt;

  factory HistoryEntry.fromRow(Map<String, Object?> r) => HistoryEntry(
        id: r['id'] as int,
        url: r['url'] as String,
        title: r['title'] as String,
        host: r['host'] as String,
        visitedAt: DateTime.fromMillisecondsSinceEpoch(r['visited_at'] as int),
      );
}

enum HistoryRange { lastHour, today, last7Days, last4Weeks, all }

class HistoryRepository {
  HistoryRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final Database _db;
  final DateTime Function() _clock;

  /// Collapses rapid reloads/redirects of the same URL into one entry.
  static const dedupeWindow = Duration(minutes: 1);

  Future<void> record(Uri url, String title) async {
    if (url.scheme != 'http' && url.scheme != 'https') return;
    final now = _clock();
    final urlStr = url.toString();
    final recent = await _db.query(
      'history',
      columns: ['id'],
      where: 'url = ? AND visited_at >= ?',
      whereArgs: [urlStr, now.subtract(dedupeWindow).millisecondsSinceEpoch],
      limit: 1,
    );
    if (recent.isNotEmpty) {
      await _db.update(
        'history',
        {'title': title, 'visited_at': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [recent.first['id']],
      );
      return;
    }
    await _db.insert('history', {
      'url': urlStr,
      'title': title,
      'host': url.host,
      'visited_at': now.millisecondsSinceEpoch,
    });
  }

  Future<void> updateTitle(Uri url, String title) => _db.update(
        'history',
        {'title': title},
        where: 'id = (SELECT id FROM history WHERE url = ? '
            'ORDER BY visited_at DESC LIMIT 1)',
        whereArgs: [url.toString()],
      );

  Future<List<HistoryEntry>> list({
    String query = '',
    int limit = 200,
    int offset = 0,
  }) async {
    final q = query.trim();
    final rows = await _db.query(
      'history',
      where: q.isEmpty ? null : "(title LIKE ? ESCAPE '\\' OR url LIKE ? ESCAPE '\\')",
      whereArgs: q.isEmpty ? null : ['%${escapeLike(q)}%', '%${escapeLike(q)}%'],
      orderBy: 'visited_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(HistoryEntry.fromRow).toList();
  }

  Future<void> deleteEntry(int id) =>
      _db.delete('history', where: 'id = ?', whereArgs: [id]);

  Future<int> deleteRange(HistoryRange range) {
    if (range == HistoryRange.all) return _db.delete('history');
    final now = _clock();
    final from = switch (range) {
      HistoryRange.lastHour => now.subtract(const Duration(hours: 1)),
      HistoryRange.today => DateTime(now.year, now.month, now.day),
      HistoryRange.last7Days => now.subtract(const Duration(days: 7)),
      HistoryRange.last4Weeks => now.subtract(const Duration(days: 28)),
      HistoryRange.all => DateTime(0),
    };
    return _db.delete('history',
        where: 'visited_at >= ?', whereArgs: [from.millisecondsSinceEpoch]);
  }

  Future<int> deleteHost(String host) =>
      _db.delete('history', where: 'host = ?', whereArgs: [host]);

  /// Suggestions for the address bar, most recent first, unique by URL.
  Future<List<HistoryEntry>> suggest(String prefix, {int limit = 6}) async {
    final p = prefix.trim();
    if (p.isEmpty) return const [];
    final like = '%${escapeLike(p)}%';
    final rows = await _db.rawQuery('''
      SELECT id, url, title, host, MAX(visited_at) AS visited_at FROM history
      WHERE url LIKE ? ESCAPE '\\' OR title LIKE ? ESCAPE '\\'
      GROUP BY url ORDER BY visited_at DESC LIMIT ?''', [like, like, limit]);
    return rows.map(HistoryEntry.fromRow).toList();
  }
}
