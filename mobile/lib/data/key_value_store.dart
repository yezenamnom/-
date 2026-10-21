import 'package:shared_preferences/shared_preferences.dart';

/// Small persistence seam so services can be unit-tested without plugins.
abstract class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  int? getInt(String key);
  Future<void> setInt(String key, int value);
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}

class PrefsStore implements KeyValueStore {
  PrefsStore(this._prefs);
  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);
  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  @override
  int? getInt(String key) => _prefs.getInt(key);
  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
  @override
  bool? getBool(String key) => _prefs.getBool(key);
  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

class MemoryStore implements KeyValueStore {
  final Map<String, Object> values = {};

  @override
  String? getString(String key) => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
  @override
  int? getInt(String key) => values[key] as int?;
  @override
  Future<void> setInt(String key, int value) async => values[key] = value;
  @override
  bool? getBool(String key) => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}
