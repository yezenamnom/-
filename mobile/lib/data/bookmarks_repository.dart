import 'package:sqflite/sqflite.dart';

import 'sql_utils.dart';

class Bookmark {
  const Bookmark({
    required this.id,
    required this.url,
    required this.title,
    required this.folderId,
    required this.position,
  });

  final int id;
  final String url;
  final String title;
  final int? folderId;
  final int position;

  factory Bookmark.fromRow(Map<String, Object?> r) => Bookmark(
        id: r['id'] as int,
        url: r['url'] as String,
        title: r['title'] as String,
        folderId: r['folder_id'] as int?,
        position: r['position'] as int,
      );
}

class BookmarkFolder {
  const BookmarkFolder({
    required this.id,
    required this.name,
    required this.parentId,
  });

  final int id;
  final String name;
  final int? parentId;

  factory BookmarkFolder.fromRow(Map<String, Object?> r) => BookmarkFolder(
        id: r['id'] as int,
        name: r['name'] as String,
        parentId: r['parent_id'] as int?,
      );
}

class BookmarksRepository {
  BookmarksRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;
  final Database _db;
  final DateTime Function() _clock;

  String _folderWhere(int? folderId) =>
      folderId == null ? 'folder_id IS NULL' : 'folder_id = ?';

  Future<List<Bookmark>> list({int? folderId}) async {
    final rows = await _db.query(
      'bookmarks',
      where: _folderWhere(folderId),
      whereArgs: folderId == null ? null : [folderId],
      orderBy: 'position ASC, id ASC',
    );
    return rows.map(Bookmark.fromRow).toList();
  }

  Future<List<Bookmark>> search(String query) async {
    final like = '%${escapeLike(query.trim())}%';
    final rows = await _db.query('bookmarks',
        where: "title LIKE ? ESCAPE '\\' OR url LIKE ? ESCAPE '\\'",
        whereArgs: [like, like],
        orderBy: 'title COLLATE NOCASE');
    return rows.map(Bookmark.fromRow).toList();
  }

  Future<List<BookmarkFolder>> folders({int? parentId}) async {
    final rows = await _db.query(
      'bookmark_folders',
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'position ASC, name COLLATE NOCASE',
    );
    return rows.map(BookmarkFolder.fromRow).toList();
  }

  Future<List<BookmarkFolder>> allFolders() async {
    final rows =
        await _db.query('bookmark_folders', orderBy: 'name COLLATE NOCASE');
    return rows.map(BookmarkFolder.fromRow).toList();
  }

  Future<bool> isBookmarked(String url) async {
    final r = await _db.query('bookmarks',
        columns: ['id'], where: 'url = ?', whereArgs: [url], limit: 1);
    return r.isNotEmpty;
  }

  Future<int> add(String url, String title, {int? folderId}) async {
    final pos = Sqflite.firstIntValue(await _db.rawQuery(
            'SELECT COALESCE(MAX(position), -1) + 1 FROM bookmarks WHERE '
            '${_folderWhere(folderId)}',
            folderId == null ? null : [folderId])) ??
        0;
    return _db.insert('bookmarks', {
      'url': url,
      'title': title.trim().isEmpty ? url : title.trim(),
      'folder_id': folderId,
      'position': pos,
      'created_at': _clock().millisecondsSinceEpoch,
    });
  }

  Future<void> update(int id, {String? title, String? url, int? folderId,
      bool moveToRoot = false}) async {
    final values = <String, Object?>{
      'title': ?title,
      'url': ?url,
      'folder_id': ?folderId,
      if (moveToRoot) 'folder_id': null,
    };
    if (values.isEmpty) return;
    await _db.update('bookmarks', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> removeByUrl(String url) =>
      _db.delete('bookmarks', where: 'url = ?', whereArgs: [url]);

  Future<void> remove(int id) =>
      _db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);

  Future<void> reorder(List<int> idsInOrder) async {
    final batch = _db.batch();
    for (final (i, id) in idsInOrder.indexed) {
      batch.update('bookmarks', {'position': i},
          where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<int> addFolder(String name, {int? parentId}) => _db.insert(
        'bookmark_folders',
        {
          'name': name.trim(),
          'parent_id': parentId,
          'created_at': _clock().millisecondsSinceEpoch,
        },
      );

  Future<void> renameFolder(int id, String name) => _db.update(
      'bookmark_folders', {'name': name.trim()},
      where: 'id = ?', whereArgs: [id]);

  /// Deletes the folder, its subfolders and their bookmarks (cascade).
  Future<void> removeFolder(int id) =>
      _db.delete('bookmark_folders', where: 'id = ?', whereArgs: [id]);
}
