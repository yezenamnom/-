import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'ads/ads_policy.dart';
import 'ads/ads_service.dart';
import 'ads/consent_service.dart';
import 'app.dart';
import 'app_providers.dart';
import 'billing/subscription_service.dart';
import 'blocking/blocking_service.dart';
import 'browser/private_session.dart';
import 'browser/tabs_controller.dart';
import 'config/config_service.dart';
import 'config/config_verifier.dart';
import 'core/app_env.dart';
import 'data/blob_store.dart';
import 'data/bookmarks_repository.dart';
import 'data/database.dart';
import 'data/history_repository.dart';
import 'data/key_value_store.dart';
import 'data/settings_controller.dart';
import 'data/shortcuts_repository.dart';
import 'data/site_permissions_repository.dart';
import 'data/tabs_repository.dart';
import 'downloads/downloads_service.dart';
import 'media/pip_service.dart';
import 'reports/report_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isAndroid = Platform.isAndroid;
  final prefs = PrefsStore(await SharedPreferences.getInstance());
  final supportDir = await getApplicationSupportDirectory();
  final docsDir = await getApplicationDocumentsDirectory();
  final db = await AppDatabase.open(p.join(await getDatabasesPath(), 'vela.db'));
  final info = await PackageInfo.fromPlatform();
  final verifier = ConfigVerifier.fromBase64Url(AppEnv.configPublicKey);
  final platform = isAndroid ? 'android' : 'ios';

  if (isAndroid && kDebugMode) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  final privateSession = PrivateSession(isAndroid: isAndroid);
  // Remove any private profile left over from a crash, before any WebView.
  await privateSession.cleanupLeftovers();

  final settings = SettingsController(prefs);
  final config = ConfigService(
    store: prefs,
    verifier: verifier,
    baseUrl: AppEnv.configBaseUrl,
    appVersion: info.version,
    platform: platform,
    allowInsecure: AppEnv.allowInsecureConfigServer,
  );
  await config.loadCached();

  final blocking = BlockingService(
    store: prefs,
    blobs: FileBlobStore(Directory(p.join(supportDir.path, 'blocklists'))),
    loadBundled: () async =>
        (await rootBundle.load('assets/blocklists/starter.json'))
            .buffer
            .asUint8List(),
    baseUrl: AppEnv.configBaseUrl,
  );
  await blocking.init();

  final subscription = SubscriptionService(
    store: prefs,
    verifier: verifier,
    baseUrl: AppEnv.configBaseUrl,
    productIds: const [
      String.fromEnvironment('SUB_PRODUCT_MONTHLY'),
      String.fromEnvironment('SUB_PRODUCT_YEARLY'),
    ],
    platform: platform,
    iap: InAppPurchase.instance,
  );

  final ads = AdsService(
    consent: UmpConsentGate(),
    platform: isAndroid ? AdPlatform.android : AdPlatform.ios,
    useProductionAds: AppEnv.useProductionAds,
    config: () => config.config.ads,
    adFree: () => subscription.adFree,
  );

  final tabsRepo = TabsRepository(db.db);
  final tabs = TabsController(
    repository: settings.restoreTabs ? tabsRepo : null,
    onFreeze: (tab) {
      final k = tab.keepAlive;
      if (k != null) InAppWebViewController.disposeKeepAlive(k);
    },
    onPrivateSessionEnded: (closed) async {
      for (final t in closed) {
        final k = t.keepAlive;
        if (k != null) await InAppWebViewController.disposeKeepAlive(k);
      }
      await privateSession.end();
    },
  );
  if (settings.restoreTabs) {
    await tabs.restore();
  } else {
    await tabsRepo.saveAll(const []);
  }

  final downloads = DownloadsService(
    db: db.db,
    directory: Directory(p.join(docsDir.path, 'Downloads')),
  );
  await downloads.load();

  final pip = PipService(isAndroid: isAndroid);

  runApp(ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => settings),
      configProvider.overrideWith((ref) => config),
      blockingProvider.overrideWith((ref) => blocking),
      tabsProvider.overrideWith((ref) => tabs),
      adsProvider.overrideWith((ref) => ads),
      subscriptionProvider.overrideWith((ref) => subscription),
      downloadsProvider.overrideWith((ref) => downloads),
      pipProvider.overrideWith((ref) => pip),
      historyRepoProvider.overrideWithValue(HistoryRepository(db.db)),
      bookmarksRepoProvider.overrideWithValue(BookmarksRepository(db.db)),
      shortcutsRepoProvider
          .overrideWithValue(ShortcutsRepository(db.db, prefs)),
      sitePermissionsProvider
          .overrideWithValue(SitePermissionsRepository(db.db)),
      privateSessionProvider.overrideWithValue(privateSession),
      reportServiceProvider
          .overrideWithValue(ReportService(baseUrl: AppEnv.configBaseUrl)),
    ],
    child: const VelaApp(),
  ));

  // Network work happens after the first frame and never blocks browsing.
  unawaited(() async {
    await config.refresh();
    await blocking.applyConfig(config.config.blocking);
    config.addListener(
        () => unawaited(blocking.applyConfig(config.config.blocking)));
    await subscription.init();
    await ads.start();
  }());
}
