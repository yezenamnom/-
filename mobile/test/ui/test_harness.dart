import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vela_browser/ads/ads_policy.dart';
import 'package:vela_browser/ads/ads_service.dart';
import 'package:vela_browser/ads/consent_service.dart';
import 'package:vela_browser/app.dart';
import 'package:vela_browser/app_providers.dart';
import 'package:vela_browser/billing/subscription_service.dart';
import 'package:vela_browser/blocking/blocking_service.dart';
import 'package:vela_browser/browser/private_session.dart';
import 'package:vela_browser/browser/tabs_controller.dart';
import 'package:vela_browser/config/config_service.dart';
import 'package:vela_browser/config/config_verifier.dart';
import 'package:vela_browser/data/blob_store.dart';
import 'package:vela_browser/data/bookmarks_repository.dart';
import 'package:vela_browser/data/database.dart';
import 'package:vela_browser/data/history_repository.dart';
import 'package:vela_browser/data/key_value_store.dart';
import 'package:vela_browser/data/settings_controller.dart';
import 'package:vela_browser/data/shortcuts_repository.dart';
import 'package:vela_browser/data/site_permissions_repository.dart';
import 'package:vela_browser/downloads/downloads_service.dart';
import 'package:vela_browser/media/pip_service.dart';
import 'package:vela_browser/reports/report_service.dart';

/// Real services wired to in-memory storage; no platform channels, no
/// network, no WebView (widget tests only exercise app UI).
class TestApp {
  TestApp._(this.db, this.store, this.settings, this.tabs, this.widget);

  final AppDatabase db;
  final MemoryStore store;
  final SettingsController settings;
  final TabsController tabs;
  final Widget widget;

  static Future<TestApp> create({String? locale}) async {
    sqfliteFfiInit();
    final db = await AppDatabase.open(inMemoryDatabasePath,
        factory: databaseFactoryFfiNoIsolate);
    final store = MemoryStore();
    if (locale != null) store.values['ui.locale'] = locale;
    final settings = SettingsController(store);
    final verifier = ConfigVerifier.fromBase64Url('');
    final config = ConfigService(
      store: store,
      verifier: verifier,
      baseUrl: '',
      appVersion: '1.0.0',
      platform: 'android',
    );
    final bundled = File('assets/blocklists/starter.json').readAsBytesSync();
    final blocking = BlockingService(
      store: store,
      blobs: MemoryBlobStore(),
      loadBundled: () async => bundled,
      baseUrl: '',
    );
    await blocking.init();
    final subscription = SubscriptionService(
      store: store,
      verifier: verifier,
      baseUrl: '',
      productIds: const [],
      platform: 'android',
    );
    await subscription.init();
    final ads = AdsService(
      consent: NoConsentGate(),
      platform: AdPlatform.android,
      useProductionAds: false,
      config: () => config.config.ads,
      adFree: () => subscription.adFree,
      sdkAvailable: false,
    );
    final tabs = TabsController(repository: null);
    final downloads = DownloadsService(
      db: db.db,
      directory: Directory.systemTemp.createTempSync('vela_dl'),
    );
    final widget = ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        configProvider.overrideWith((ref) => config),
        blockingProvider.overrideWith((ref) => blocking),
        tabsProvider.overrideWith((ref) => tabs),
        adsProvider.overrideWith((ref) => ads),
        subscriptionProvider.overrideWith((ref) => subscription),
        downloadsProvider.overrideWith((ref) => downloads),
        pipProvider.overrideWith((ref) => PipService(isAndroid: false)),
        historyRepoProvider.overrideWithValue(HistoryRepository(db.db)),
        bookmarksRepoProvider.overrideWithValue(BookmarksRepository(db.db)),
        shortcutsRepoProvider
            .overrideWithValue(ShortcutsRepository(db.db, store)),
        sitePermissionsProvider
            .overrideWithValue(SitePermissionsRepository(db.db)),
        privateSessionProvider
            .overrideWithValue(PrivateSession(isAndroid: false)),
        reportServiceProvider.overrideWithValue(ReportService(baseUrl: '')),
      ],
      child: const VelaApp(),
    );
    return TestApp._(db, store, settings, tabs, widget);
  }
}
