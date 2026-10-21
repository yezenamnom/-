import 'package:sqflite/sqflite.dart';

/// Local browsing database. Lives only on the device; nothing in it is ever
/// sent to the admin server. Private tabs never write here.
class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static const version = 1;

  static Future<AppDatabase> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, v) => _migrate(db, 0, v),
        onUpgrade: _migrate,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    final batch = db.batch();
    if (from < 1) {
      batch.execute('''
        CREATE TABLE tabs (
          id TEXT PRIMARY KEY,
          url TEXT NOT NULL,
          title TEXT NOT NULL DEFAULT '',
          position INTEGER NOT NULL,
          last_active INTEGER NOT NULL,
          is_current INTEGER NOT NULL DEFAULT 0
        )''');
      batch.execute('''
        CREATE TABLE history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          url TEXT NOT NULL,
          title TEXT NOT NULL DEFAULT '',
          host TEXT NOT NULL DEFAULT '',
          visited_at INTEGER NOT NULL
        )''');
      batch.execute('CREATE INDEX history_visited ON history(visited_at)');
      batch.execute('CREATE INDEX history_url ON history(url)');
      batch.execute('''
        CREATE TABLE bookmark_folders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          parent_id INTEGER REFERENCES bookmark_folders(id) ON DELETE CASCADE,
          position INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )''');
      batch.execute('''
        CREATE TABLE bookmarks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          url TEXT NOT NULL,
          title TEXT NOT NULL DEFAULT '',
          folder_id INTEGER REFERENCES bookmark_folders(id) ON DELETE CASCADE,
          position INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )''');
      batch.execute('CREATE INDEX bookmarks_url ON bookmarks(url)');
      batch.execute('''
        CREATE TABLE shortcuts (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          url TEXT NOT NULL,
          icon_key TEXT,
          color TEXT,
          position INTEGER NOT NULL,
          remote_id TEXT
        )''');
      batch.execute('''
        CREATE TABLE downloads (
          id TEXT PRIMARY KEY,
          url TEXT NOT NULL,
          file_name TEXT NOT NULL,
          path TEXT NOT NULL,
          mime TEXT,
          total_bytes INTEGER,
          received_bytes INTEGER NOT NULL DEFAULT 0,
          status TEXT NOT NULL,
          error TEXT,
          created_at INTEGER NOT NULL
        )''');
      batch.execute('''
        CREATE TABLE site_permissions (
          host TEXT NOT NULL,
          permission TEXT NOT NULL,
          decision TEXT NOT NULL,
          PRIMARY KEY (host, permission)
        )''');
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() => db.close();
}
