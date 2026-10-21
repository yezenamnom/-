import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vela_browser/config/default_config.dart';
import 'package:vela_browser/config/remote_config.dart';
import 'package:vela_browser/data/bookmarks_repository.dart';
import 'package:vela_browser/data/database.dart';
import 'package:vela_browser/data/history_repository.dart';
import 'package:vela_browser/data/key_value_store.dart';
import 'package:vela_browser/data/shortcuts_repository.dart';
import 'package:vela_browser/data/site_permissions_repository.dart';
import 'package:vela_browser/data/tabs_repository.dart';

void main() {
  sqfliteFfiInit();
  late AppDatabase appDb;
  var now = DateTime(2026, 10, 21, 15);
  DateTime clock() => now;

  setUp(() async {
    now = DateTime(2026, 10, 21, 15);
    appDb = await AppDatabase.open(inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate);
  });
  tearDown(() => appDb.close());

  group('history', () {
    test('records http(s) only and dedupes rapid repeats', () async {
      final h = HistoryRepository(appDb.db, clock: clock);
      await h.record(Uri.parse('https://a.com/'), 'A');
      await h.record(Uri.parse('https://a.com/'), 'A2');
      await h.record(Uri.parse('about:blank'), '');
      await h.record(Uri.parse('file:///x'), '');
      var all = await h.list();
      expect(all.length, 1);
      expect(all.first.title, 'A2');
      now = now.add(const Duration(minutes: 5));
      await h.record(Uri.parse('https://a.com/'), 'A');
      all = await h.list();
      expect(all.length, 2);
    });

    test('search escapes LIKE wildcards', () async {
      final h = HistoryRepository(appDb.db, clock: clock);
      await h.record(Uri.parse('https://a.com/100%25'), '100% real');
      await h.record(Uri.parse('https://b.com/'), 'Bee');
      expect((await h.list(query: '%')).length, 1);
      expect((await h.list(query: '_')).length, 0);
      expect((await h.list(query: 'bee')).single.host, 'b.com');
      expect((await h.suggest('b.c')).single.url, 'https://b.com/');
    });

    test('delete by range', () async {
      final h = HistoryRepository(appDb.db, clock: clock);
      now = DateTime(2026, 10, 1, 12);
      await h.record(Uri.parse('https://old.com/'), 'old');
      now = DateTime(2026, 10, 21, 9);
      await h.record(Uri.parse('https://morning.com/'), 'm');
      now = DateTime(2026, 10, 21, 14, 30);
      await h.record(Uri.parse('https://recent.com/'), 'r');
      now = DateTime(2026, 10, 21, 15);
      expect(await h.deleteRange(HistoryRange.lastHour), 1);
      expect(await h.deleteRange(HistoryRange.today), 1);
      expect((await h.list()).single.host, 'old.com');
      expect(await h.deleteRange(HistoryRange.all), 1);
    });
  });

  group('bookmarks', () {
    test('folders, ordering, cascade delete', () async {
      final b = BookmarksRepository(appDb.db, clock: clock);
      final f = await b.addFolder('Videos');
      final sub = await b.addFolder('Music', parentId: f);
      await b.add('https://a.com', 'A');
      await b.add('https://b.com', '');
      await b.add('https://c.com', 'C', folderId: f);
      await b.add('https://d.com', 'D', folderId: sub);
      final root = await b.list();
      expect(root.map((e) => e.title), ['A', 'https://b.com']);
      await b.reorder([root[1].id, root[0].id]);
      expect((await b.list()).first.url, 'https://b.com');
      expect(await b.isBookmarked('https://c.com'), isTrue);
      expect((await b.folders()).single.name, 'Videos');
      expect((await b.folders(parentId: f)).single.name, 'Music');
      await b.removeFolder(f);
      expect(await b.isBookmarked('https://c.com'), isFalse);
      expect(await b.isBookmarked('https://d.com'), isFalse);
      expect((await b.allFolders()), isEmpty);
      expect((await b.search('a')).single.url, 'https://a.com');
    });
  });

  test('tabs persist and restore order/current', () async {
    final t = TabsRepository(appDb.db);
    await t.saveAll([
      StoredTab(
          id: '1',
          url: 'https://a.com',
          title: 'A',
          position: 1,
          lastActive: now,
          isCurrent: false),
      StoredTab(
          id: '2',
          url: 'https://b.com',
          title: 'B',
          position: 0,
          lastActive: now,
          isCurrent: true),
    ]);
    final loaded = await t.load();
    expect(loaded.map((e) => e.id), ['2', '1']);
    expect(loaded.first.isCurrent, isTrue);
    await t.saveAll([]);
    expect(await t.load(), isEmpty);
  });

  test('site permissions', () async {
    final p = SitePermissionsRepository(appDb.db);
    expect(await p.get('a.com', SitePermission.camera), isNull);
    await p.set('a.com', SitePermission.camera, PermissionDecision.allow);
    await p.set('a.com', SitePermission.camera, PermissionDecision.deny);
    expect(await p.get('a.com', SitePermission.camera), PermissionDecision.deny);
    expect((await p.forHost('a.com')).length, 1);
    await p.clearHost('a.com');
    expect(await p.get('a.com', SitePermission.camera), isNull);
  });

  group('shortcuts', () {
    final remote = buildDefaultConfig().shortcuts;

    test('uncustomized users follow admin defaults', () {
      final v = computeShortcutsView(
        remote: remote,
        customized: false,
        userItems: const [],
        seenRemoteIds: const {},
        dismissedRemoteIds: const {},
        languageCode: 'ar',
      );
      expect(v.items.first.title, 'يوتيوب');
      expect(v.suggestions, isEmpty);
    });

    test('customization is never wiped by new defaults', () async {
      final store = MemoryStore();
      final repo = ShortcutsRepository(appDb.db, store);
      final shown = [for (final r in remote) fromRemote(r, 'en')];
      // User deletes TikTok and adds their own site.
      await repo.edit(shown, remote, (items) {
        items.removeWhere((s) => s.remoteId == 'tiktok');
        items.add(ShortcutItem(
            id: ShortcutsRepository.newId(),
            title: 'Mine',
            url: 'https://mine.example'));
        return items;
      });
      final newRemote = [
        ...remote,
        const RemoteShortcut(
          id: 'vimeo',
          title: {'en': 'Vimeo'},
          url: 'https://vimeo.com/',
          iconKey: 'vimeo',
          iconAssetId: null,
          color: null,
          order: 9,
        ),
      ];
      final v = computeShortcutsView(
        remote: newRemote,
        customized: repo.customized,
        userItems: await repo.loadUserItems(),
        seenRemoteIds: repo.seenRemoteIds,
        dismissedRemoteIds: repo.dismissedRemoteIds,
        languageCode: 'en',
      );
      expect(v.items.map((e) => e.title),
          ['YouTube', 'Twitch', 'Rumble', 'Mine']);
      expect(v.suggestions.map((s) => s.id), ['vimeo'],
          reason: 'deleted tiktok is not re-suggested; new vimeo is offered');

      await repo.dismissSuggestion('vimeo');
      final v2 = computeShortcutsView(
        remote: newRemote,
        customized: true,
        userItems: await repo.loadUserItems(),
        seenRemoteIds: repo.seenRemoteIds,
        dismissedRemoteIds: repo.dismissedRemoteIds,
        languageCode: 'en',
      );
      expect(v2.suggestions, isEmpty);

      await repo.resetToDefaults();
      expect(repo.customized, isFalse);
      expect(await repo.loadUserItems(), isEmpty);
    });
  });
}
