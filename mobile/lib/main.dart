import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'data/secret_store.dart';
import 'data/settings_controller.dart';
import 'data/shortcuts_repository.dart';
import 'data/site_permissions_repository.dart';
import 'data/tabs_repository.dart';
import 'downloads/downloads_service.dart';
import 'media/pip_service.dart';
import 'reports/report_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw something immediately: on slow devices/emulators the work below can
  // take seconds, and nothing may block the first frame (ANR risk).
  runApp(const _Splash());
  try {
    runApp(await _bootstrap());
  } on Object catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(_StartupError(error: e));
  }
}

Future<Widget> _bootstrap() async {
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
    secrets: const SecureSecretStore(),
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
    desktopModeDefault: () => settings.desktopModeDefault,
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

  final app = ProviderScope(
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
  );

  // Work that touches the network or initialises Android WebView runs after
  // the UI is up and never blocks browsing.
  unawaited(() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    // Remove private profiles left over from a crash. Loading the WebView
    // provider for this is slow, so it is not done before the first frame;
    // a new private session always uses a fresh profile name anyway.
    await privateSession.cleanupLeftovers();
    await config.refresh();
    await blocking.applyConfig(config.config.blocking);
    config.addListener(
        () => unawaited(blocking.applyConfig(config.config.blocking)));
    await subscription.init();
    await ads.start();
  }());
  return app;
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFFF4FBF9),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: Color(0xFF2E7D74)),
          ),
        ),
      );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text('The app could not start. / تعذّر تشغيل التطبيق.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                SelectableText('$error', textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      );
}
