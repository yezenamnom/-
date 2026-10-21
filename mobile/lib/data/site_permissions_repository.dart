import 'package:sqflite/sqflite.dart';

enum SitePermission { camera, microphone, location }

enum PermissionDecision { allow, deny }

/// Remembered per-site decisions. A missing entry means "ask every time".
class SitePermissionsRepository {
  SitePermissionsRepository(this._db);
  final Database _db;

  Future<PermissionDecision?> get(String host, SitePermission p) async {
    final r = await _db.query('site_permissions',
        columns: ['decision'],
        where: 'host = ? AND permission = ?',
        whereArgs: [host, p.name],
        limit: 1);
    if (r.isEmpty) return null;
    return PermissionDecision.values.asNameMap()[r.first['decision']];
  }

  Future<void> set(String host, SitePermission p, PermissionDecision d) =>
      _db.insert(
        'site_permissions',
        {'host': host, 'permission': p.name, 'decision': d.name},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<Map<SitePermission, PermissionDecision>> forHost(String host) async {
    final rows = await _db
        .query('site_permissions', where: 'host = ?', whereArgs: [host]);
    final perms = SitePermission.values.asNameMap();
    final decisions = PermissionDecision.values.asNameMap();
    return {
      for (final r in rows)
        if (perms[r['permission']] != null &&
            decisions[r['decision']] != null)
          perms[r['permission']]!: decisions[r['decision']]!,
    };
  }

  Future<void> clearHost(String host) =>
      _db.delete('site_permissions', where: 'host = ?', whereArgs: [host]);

  Future<void> clearAll() => _db.delete('site_permissions');
}
