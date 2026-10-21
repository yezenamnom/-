import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vela_browser/browser/browser_tab.dart';
import 'package:vela_browser/browser/tabs_controller.dart';
import 'package:vela_browser/data/database.dart';
import 'package:vela_browser/data/tabs_repository.dart';

void main() {
  sqfliteFfiInit();
  var now = DateTime(2026, 10, 21, 12);
  DateTime clock() => now = now.add(const Duration(seconds: 1));

  test('open, select, close picks a same-kind neighbour', () async {
    final c = TabsController(repository: null, clock: clock);
    final a = c.open(url: Uri.parse('https://a.com'));
    final b = c.open(url: Uri.parse('https://b.com'));
    final p = c.open(private: true);
    expect(c.current, p);
    c.select(b.id);
    expect(c.current, b);
    await c.close(b.id);
    expect(c.current, a);
    expect(c.normalTabs.length, 1);
    expect(c.privateTabs.single, p);
    c.select(p.id);
    await c.close(p.id);
    expect(c.current, isNull, reason: 'no private tab left -> home/tab grid');
  });

  test('private session end callback fires once all private tabs close',
      () async {
    final ended = <List<BrowserTab>>[];
    final c = TabsController(
      repository: null,
      clock: clock,
      onPrivateSessionEnded: (closed) async => ended.add(closed),
    );
    final p1 = c.open(private: true);
    c.open(private: true);
    c.open(url: Uri.parse('https://normal.com'));
    await c.close(p1.id);
    expect(ended, isEmpty);
    await c.closeAll(private: true);
    expect(ended.single.length, 1);
    expect(c.normalTabs.length, 1);
    await c.closeAll(private: true);
    expect(ended.length, 1, reason: 'no event for an empty close-all');
  });

  test('ten tabs: LRU freezing spares current and media tabs', () {
    final frozen = <String>[];
    final c = TabsController(
      repository: null,
      clock: clock,
      maxLiveWebViews: 3,
      onFreeze: (t) => frozen.add(t.id),
    );
    final tabs = <BrowserTab>[];
    for (var i = 0; i < 10; i++) {
      final t = c.open(url: Uri.parse('https://s$i.com'));
      t.keepAlive = InAppWebViewKeepAlive();
      // Simulate: tab 0 starts playing audio, then the user opens more tabs.
      if (i == 0) t.mediaPlaying = true;
      tabs.add(t);
    }
    c.select(tabs[9].id);
    final live = c.tabs.where((t) => t.hasLiveWebView).toList();
    expect(live.length, 3);
    expect(live.contains(tabs[9]), isTrue);
    expect(live.contains(tabs[0]), isTrue, reason: 'media tab never frozen');
    expect(frozen.contains(tabs[0].id), isFalse);

    // Re-selecting a frozen tab schedules a reload of its URL.
    c.select(tabs[1].id);
    expect(tabs[1].frozen, isFalse);
    expect(tabs[1].pendingLoad, Uri.parse('https://s1.com'));
  });

  test('reorder and search within a group', () {
    final c = TabsController(repository: null, clock: clock);
    final a = c.open(url: Uri.parse('https://a.com'))..title = 'Alpha';
    final b = c.open(url: Uri.parse('https://b.com'))..title = 'Beta';
    c.open(private: true).title = 'Secret alpha';
    c.reorder(1, 0, private: false);
    expect(c.normalTabs, [b, a]);
    expect(c.search('alpha', private: false), [a]);
    expect(c.search('alpha', private: true).single.title, 'Secret alpha');
  });

  test('only normal tabs are persisted and restored', () async {
    final db = await AppDatabase.open(inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate);
    final repo = TabsRepository(db.db);
    final c = TabsController(repository: repo, clock: clock);
    c.open(url: Uri.parse('https://a.com')).title = 'A';
    final b = c.open(url: Uri.parse('https://b.com'));
    c.open(url: Uri.parse('https://secret.com'), private: true);
    c.open(); // empty new-tab page is not persisted
    c.select(b.id);
    await c.saveNow();

    final restored = TabsController(repository: repo, clock: clock);
    await restored.restore();
    expect(restored.tabs.map((t) => t.url.toString()),
        ['https://a.com', 'https://b.com']);
    expect(restored.tabs.every((t) => !t.isPrivate), isTrue);
    expect(restored.current?.url.toString(), 'https://b.com');
    expect(restored.current!.frozen, isTrue, reason: 'lazy webview creation');
    restored.select(restored.current!.id);
    expect(restored.current!.pendingLoad.toString(), 'https://b.com');
    c.dispose();
    restored.dispose();
    await db.close();
  });
}
