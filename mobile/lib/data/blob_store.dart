import 'dart:io';

import 'package:path/path.dart' as p;

/// Named binary blobs in the app-private support directory.
abstract class BlobStore {
  Future<List<int>?> read(String name);
  Future<void> write(String name, List<int> bytes);
  Future<void> delete(String name);
}

class FileBlobStore implements BlobStore {
  FileBlobStore(this._dir);
  final Directory _dir;

  File _file(String name) {
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name');
    }
    return File(p.join(_dir.path, name));
  }

  @override
  Future<List<int>?> read(String name) async {
    final f = _file(name);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> write(String name, List<int> bytes) async {
    await _dir.create(recursive: true);
    final tmp = File('${_file(name).path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(_file(name).path);
  }

  @override
  Future<void> delete(String name) async {
    final f = _file(name);
    if (await f.exists()) await f.delete();
  }
}

class MemoryBlobStore implements BlobStore {
  final Map<String, List<int>> blobs = {};
  @override
  Future<List<int>?> read(String name) async => blobs[name];
  @override
  Future<void> write(String name, List<int> bytes) async => blobs[name] = bytes;
  @override
  Future<void> delete(String name) async => blobs.remove(name);
}
