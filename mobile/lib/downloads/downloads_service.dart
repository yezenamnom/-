import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/file_names.dart';

enum DownloadStatus { running, completed, failed, canceled }

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.path,
    required this.mime,
    required this.totalBytes,
    required this.receivedBytes,
    required this.status,
    required this.createdAt,
    this.error,
  });

  final String id;
  final String url;
  final String fileName;
  final String path;
  final String? mime;
  int? totalBytes;
  int receivedBytes;
  DownloadStatus status;
  final DateTime createdAt;
  String? error;

  double? get progress => (totalBytes == null || totalBytes == 0)
      ? null
      : (receivedBytes / totalBytes!).clamp(0, 1).toDouble();
}

class DownloadRequest {
  const DownloadRequest({
    required this.url,
    this.suggestedFileName,
    this.mimeType,
    this.contentDisposition,
    this.headers = const {},
  });

  final Uri url;
  final String? suggestedFileName;
  final String? mimeType;
  final String? contentDisposition;

  /// Only User-Agent/Referer/Cookie for the same site, never sent elsewhere.
  final Map<String, String> headers;
}

/// Direct downloads the source offers (links with Content-Disposition,
/// files the page asks to download). Files go to an app-private folder,
/// are never executed or opened automatically, and are shared via the OS
/// share sheet on request.
class DownloadsService extends ChangeNotifier {
  DownloadsService({
    required Database db,
    required Directory directory,
    http.Client Function()? clientFactory,
    DateTime Function()? clock,
  })  : _db = db,
        _dir = directory,
        _clientFactory = clientFactory ?? http.Client.new,
        _clock = clock ?? DateTime.now;

  static const maxBytes = 4 * 1024 * 1024 * 1024; // 4 GiB

  final Database _db;
  final Directory _dir;
  final http.Client Function() _clientFactory;
  final DateTime Function() _clock;

  final List<DownloadItem> _items = [];
  final Map<String, http.Client> _active = {};
  final Map<String, DownloadRequest> _requests = {};

  List<DownloadItem> get items => List.unmodifiable(_items);
  Directory get directory => _dir;

  Future<void> load() async {
    final rows = await _db.query('downloads', orderBy: 'created_at DESC');
    _items
      ..clear()
      ..addAll(rows.map((r) {
        var status = DownloadStatus.values.asNameMap()[r['status']] ??
            DownloadStatus.failed;
        // A download that was running when the app died is not resumable.
        if (status == DownloadStatus.running) status = DownloadStatus.failed;
        return DownloadItem(
          id: r['id'] as String,
          url: r['url'] as String,
          fileName: r['file_name'] as String,
          path: r['path'] as String,
          mime: r['mime'] as String?,
          totalBytes: r['total_bytes'] as int?,
          receivedBytes: r['received_bytes'] as int,
          status: status,
          error: r['error'] as String?,
          createdAt:
              DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
        );
      }));
    notifyListeners();
  }

  Future<DownloadItem?> start(DownloadRequest req) async {
    if (req.url.scheme != 'https' && req.url.scheme != 'http') return null;
    await _dir.create(recursive: true);
    final rawName = fileNameFromContentDisposition(req.contentDisposition) ??
        req.suggestedFileName ??
        (req.url.pathSegments.isEmpty ? null : req.url.pathSegments.last);
    final existing = {
      ..._items.map((i) => i.fileName),
      ...await _dir.list().map((e) => p.basename(e.path)).toList(),
    };
    final name = uniqueFileName(sanitizeFileName(rawName), existing);
    final path = p.join(_dir.path, name);
    // Defence in depth: the final path must stay inside the folder.
    if (!p.isWithin(_dir.path, path)) return null;

    final item = DownloadItem(
      id: const Uuid().v4(),
      url: req.url.toString(),
      fileName: name,
      path: path,
      mime: req.mimeType,
      totalBytes: null,
      receivedBytes: 0,
      status: DownloadStatus.running,
      createdAt: _clock(),
    );
    _items.insert(0, item);
    _requests[item.id] = req;
    await _persist(item);
    notifyListeners();
    unawaited(_run(item, req));
    return item;
  }

  Future<void> _run(DownloadItem item, DownloadRequest req) async {
    final client = _clientFactory();
    _active[item.id] = client;
    final part = File('${item.path}.part');
    IOSink? sink;
    try {
      final request = http.Request('GET', req.url)
        ..followRedirects = true
        ..maxRedirects = 5;
      request.headers.addAll(req.headers);
      final res = await client.send(request);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      item.totalBytes = res.contentLength;
      if ((item.totalBytes ?? 0) > maxBytes) {
        throw const FileSystemException('file too large');
      }
      sink = part.openWrite();
      var lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final chunk in res.stream) {
        if (item.status == DownloadStatus.canceled) break;
        item.receivedBytes += chunk.length;
        if (item.receivedBytes > maxBytes) {
          throw const FileSystemException('file too large');
        }
        sink.add(chunk);
        final now = _clock();
        if (now.difference(lastNotify).inMilliseconds > 250) {
          lastNotify = now;
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (item.status == DownloadStatus.canceled) {
        if (await part.exists()) await part.delete();
      } else {
        await part.rename(item.path);
        item.status = DownloadStatus.completed;
      }
    } on Object catch (e) {
      await sink?.close();
      if (await part.exists()) await part.delete();
      if (item.status != DownloadStatus.canceled) {
        item
          ..status = DownloadStatus.failed
          ..error = e is HttpException ? e.message : e.runtimeType.toString();
      }
    } finally {
      client.close();
      _active.remove(item.id);
      await _persist(item);
      notifyListeners();
    }
  }

  Future<void> cancel(String id) async {
    final item = _byId(id);
    if (item == null || item.status != DownloadStatus.running) return;
    item.status = DownloadStatus.canceled;
    _active[id]?.close();
    await _persist(item);
    notifyListeners();
  }

  Future<DownloadItem?> retry(String id) async {
    final item = _byId(id);
    if (item == null) return null;
    final req = _requests[id] ?? DownloadRequest(url: Uri.parse(item.url));
    await delete(id);
    return start(DownloadRequest(
      url: req.url,
      suggestedFileName: item.fileName.replaceFirst(RegExp(r'\.download$'), ''),
      mimeType: req.mimeType,
      headers: req.headers,
    ));
  }

  Future<void> delete(String id) async {
    final item = _byId(id);
    if (item == null) return;
    if (item.status == DownloadStatus.running) await cancel(id);
    final f = File(item.path);
    if (p.isWithin(_dir.path, item.path) && await f.exists()) await f.delete();
    _items.remove(item);
    _requests.remove(id);
    await _db.delete('downloads', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  DownloadItem? _byId(String id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  Future<void> _persist(DownloadItem i) => _db.insert(
        'downloads',
        {
          'id': i.id,
          'url': i.url,
          'file_name': i.fileName,
          'path': i.path,
          'mime': i.mime,
          'total_bytes': i.totalBytes,
          'received_bytes': i.receivedBytes,
          'status': i.status.name,
          'error': i.error,
          'created_at': i.createdAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
