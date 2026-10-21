import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'ads/ads_service.dart';
import 'billing/subscription_service.dart';
import 'blocking/blocking_service.dart';
import 'browser/private_session.dart';
import 'browser/tabs_controller.dart';
import 'config/config_service.dart';
import 'data/bookmarks_repository.dart';
import 'data/history_repository.dart';
import 'data/settings_controller.dart';
import 'data/shortcuts_repository.dart';
import 'data/site_permissions_repository.dart';
import 'downloads/downloads_service.dart';
import 'media/pip_service.dart';
import 'reports/report_service.dart';

/// All providers are overridden in main.dart with instances created during
/// bootstrap (and with fakes in widget tests).
Never _missing() => throw UnimplementedError('override in ProviderScope');

final settingsProvider =
    ChangeNotifierProvider<SettingsController>((ref) => _missing());
final configProvider =
    ChangeNotifierProvider<ConfigService>((ref) => _missing());
final blockingProvider =
    ChangeNotifierProvider<BlockingService>((ref) => _missing());
final tabsProvider = ChangeNotifierProvider<TabsController>((ref) => _missing());
final adsProvider = ChangeNotifierProvider<AdsService>((ref) => _missing());
final subscriptionProvider =
    ChangeNotifierProvider<SubscriptionService>((ref) => _missing());
final downloadsProvider =
    ChangeNotifierProvider<DownloadsService>((ref) => _missing());
final pipProvider = ChangeNotifierProvider<PipService>((ref) => _missing());

final historyRepoProvider = Provider<HistoryRepository>((ref) => _missing());
final bookmarksRepoProvider =
    Provider<BookmarksRepository>((ref) => _missing());
final shortcutsRepoProvider =
    Provider<ShortcutsRepository>((ref) => _missing());
final sitePermissionsProvider =
    Provider<SitePermissionsRepository>((ref) => _missing());
final privateSessionProvider = Provider<PrivateSession>((ref) => _missing());
final reportServiceProvider = Provider<ReportService>((ref) => _missing());

/// Bumped when bookmarks/history change so lists rebuild.
final dataRevisionProvider = StateProvider<int>((ref) => 0);
