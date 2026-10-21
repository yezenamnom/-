import 'package:flutter/material.dart';

import '../core/search_engines.dart';
import 'key_value_store.dart';

/// User preferences stored on the device only.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);
  final KeyValueStore _store;

  static const supportedLanguages = ['ar', 'en', 'de'];

  ThemeMode get themeMode => switch (_store.getString('ui.theme')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode m) async {
    await _store.setString('ui.theme', m.name);
    notifyListeners();
  }

  /// Null = follow the system language.
  Locale? get locale {
    final code = _store.getString('ui.locale');
    return supportedLanguages.contains(code) ? Locale(code!) : null;
  }

  Future<void> setLocale(Locale? l) async {
    if (l == null) {
      await _store.remove('ui.locale');
    } else {
      await _store.setString('ui.locale', l.languageCode);
    }
    notifyListeners();
  }

  SearchEngine get searchEngine =>
      searchEngineById(_store.getString('browser.searchEngine'));

  Future<void> setSearchEngine(String id) async {
    await _store.setString('browser.searchEngine', id);
    notifyListeners();
  }

  bool _flag(String key, bool def) => _store.getBool(key) ?? def;
  Future<void> _setFlag(String key, bool v) async {
    await _store.setBool(key, v);
    notifyListeners();
  }

  bool get restoreTabs => _flag('browser.restoreTabs', true);
  Future<void> setRestoreTabs(bool v) => _setFlag('browser.restoreTabs', v);

  bool get javascriptEnabled => _flag('browser.javascript', true);
  Future<void> setJavascriptEnabled(bool v) =>
      _setFlag('browser.javascript', v);

  /// Third-party cookies in normal tabs. Always blocked in private tabs.
  bool get thirdPartyCookies => _flag('browser.thirdPartyCookies', true);
  Future<void> setThirdPartyCookies(bool v) =>
      _setFlag('browser.thirdPartyCookies', v);

  bool get blockPopups => _flag('browser.blockPopups', true);
  Future<void> setBlockPopups(bool v) => _setFlag('browser.blockPopups', v);

  /// Keep audio of the current tab running when the app goes to the
  /// background, where the OS and the site allow it.
  bool get backgroundAudio => _flag('media.backgroundAudio', true);
  Future<void> setBackgroundAudio(bool v) => _setFlag('media.backgroundAudio', v);

  /// Android: enter picture-in-picture when leaving the app during
  /// fullscreen video.
  bool get autoPip => _flag('media.autoPip', true);
  Future<void> setAutoPip(bool v) => _setFlag('media.autoPip', v);

  bool get desktopModeDefault => _flag('browser.desktopDefault', false);
  Future<void> setDesktopModeDefault(bool v) =>
      _setFlag('browser.desktopDefault', v);

  double get textScale =>
      ((_store.getInt('browser.textZoom') ?? 100).clamp(50, 300)) / 100;
  Future<void> setTextZoom(int percent) async {
    await _store.setInt('browser.textZoom', percent.clamp(50, 300));
    notifyListeners();
  }

  bool get onboardingDone => _flag('app.onboardingDone', false);
  Future<void> setOnboardingDone() => _setFlag('app.onboardingDone', true);
}
