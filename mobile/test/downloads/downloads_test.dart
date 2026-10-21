import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vela_browser/data/database.dart';
import 'package:vela_browser/downloads/downloads_service.dart';
import 'package:vela_browser/reports/report_service.dart';

/// Real HTTP server on 127.0.0.1 (no mocks) serving test files.
Future<HttpServer> startServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((req) async {
    final res = req.response;
    switch (req.uri.path) {
      case '/report.pdf':
        res.headers.set('content-disposition',
            'attachment; filename="../../../etc/evil.pdf"');
        res.headers.contentLength = 5;
        res.add([37, 80, 68, 70, 10]);
      case '/app.apk':
        res.add([1, 2, 3]);
      case '/slow':
        res.headers.contentLength = 1000000;
        res.add(List.filled(1000, 0));
        await res.flush();
        await Future<void>.delayed(const Duration(seconds: 5));
      case '/cookie':
        res.write(req.headers.value('cookie') ?? 'none');
      default:
        res.statusCode = 404;
    }
    await res.close();
  });
  return server;
}

void main() {
  sqfliteFfiInit();
  late HttpServer server;
  late AppDatabase db;
  late Directory dir;
  late DownloadsService service;

  setUp(() async {
    server = await startServer();
    db = await AppDatabase.open(inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate);
    dir = Directory.systemTemp.createTempSync('vela_dl_test');
    service = DownloadsService(db: db.db, directory: dir);
  });

  tearDown(() async {
    await server.close(force: true);
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  Future<DownloadItem> finished(DownloadItem item) async {
    for (var i = 0; i < 200 && item.status == DownloadStatus.running; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return item;
  }

  test('saves inside the download folder despite a traversal filename',
      () async {
    final item = await service.start(DownloadRequest(
      url: url('/report.pdf'),
      contentDisposition: 'attachment; filename="../../../etc/evil.pdf"',
    ));
    await finished(item!);
    expect(item.status, DownloadStatus.completed);
    expect(item.fileName, 'evil.pdf');
    expect(p.isWithin(dir.path, item.path), isTrue);
    expect(File(item.path).readAsBytesSync().length, 5);
    expect(item.progress, 1.0);
  });

  test('dangerous types are renamed, duplicates get unique names', () async {
    final a = await finished((await service.start(
        DownloadRequest(url: url('/app.apk'))))!);
    final b = await finished((await service.start(
        DownloadRequest(url: url('/app.apk'))))!);
    expect(a.fileName, 'app.apk.download');
    expect(b.fileName, 'app.apk (1).download');
  });

  test('HTTP errors fail cleanly and can be retried', () async {
    final item = await finished(
        (await service.start(DownloadRequest(url: url('/missing'))))!);
    expect(item.status, DownloadStatus.failed);
    expect(item.error, contains('404'));
    expect(File('${item.path}.part').existsSync(), isFalse);
    final retried = await service.retry(item.id);
    expect(service.items.where((i) => i.id == item.id), isEmpty);
    await finished(retried!);
    expect(retried.status, DownloadStatus.failed);
  });

  test('cancel stops the transfer and removes partial data', () async {
    final item = (await service.start(DownloadRequest(url: url('/slow'))))!;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await service.cancel(item.id);
    await finished(item);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(item.status, DownloadStatus.canceled);
    expect(File(item.path).existsSync(), isFalse);
    expect(File('${item.path}.part').existsSync(), isFalse);
  });

  test('non-http schemes are refused', () async {
    expect(await service.start(DownloadRequest(url: Uri.parse('file:///etc/passwd'))),
        isNull);
    expect(
        await service.start(DownloadRequest(url: Uri.parse('data:,hello'))),
        isNull);
  });

  test('delete removes file and record; history survives restart', () async {
    final item = await finished((await service.start(
        DownloadRequest(url: url('/report.pdf'))))!);
    final reloaded = DownloadsService(db: db.db, directory: dir);
    await reloaded.load();
    expect(reloaded.items.single.fileName, item.fileName);
    await reloaded.delete(item.id);
    expect(File(item.path).existsSync(), isFalse);
    await reloaded.load();
    expect(reloaded.items, isEmpty);
  });

  test('report redaction strips URLs, e-mails and tokens', () {
    final r = UserReport(
      category: ReportCategory.siteBroken,
      message: 'Video at https://m.example.com/watch?v=abc&token=x broke, '
          'mail me at a.b@c.de, session ${'Z' * 40}',
      appVersion: '1.0.0',
      platform: 'android',
      locale: 'ar',
      siteHost: 'm.example.com',
    ).toJson();
    expect(r['message'], isNot(contains('/watch')));
    expect(r['message'], contains('m.example.com'));
    expect(r['message'], contains('[email]'));
    expect(r['message'], contains('[token]'));
    expect(r['category'], 'site_broken');
    expect(r.keys.toSet(),
        {'category', 'message', 'appVersion', 'platform', 'locale', 'siteHost'});
  });
}
