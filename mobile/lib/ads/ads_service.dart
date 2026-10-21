import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/remote_config.dart';
import 'ads_policy.dart';
import 'consent_service.dart';

/// App-UI ads only (AdMob). Never shown inside or over web content, never in
/// private tabs, never during video. Failures and no-fill are silent and
/// cannot affect browsing.
class AdsService extends ChangeNotifier {
  AdsService({
    required this.consent,
    required this.platform,
    required this.useProductionAds,
    required AdsConfig Function() config,
    required bool Function() adFree,
    DateTime Function()? clock,
    this.sdkAvailable = true,
  })  : _config = config,
        _adFree = adFree,
        _clock = clock ?? DateTime.now {
    _gate = InterstitialGate(sessionStart: _clock());
    consent.addListener(notifyListeners);
  }

  final ConsentGate consent;
  final AdPlatform platform;
  final bool useProductionAds;
  final AdsConfig Function() _config;
  final bool Function() _adFree;
  final DateTime Function() _clock;

  /// False in widget tests (no platform channel).
  final bool sdkAvailable;

  late final InterstitialGate _gate;
  bool _initialized = false;
  bool privateMode = false;
  InterstitialAd? _interstitial;

  bool get initialized => _initialized;

  AdContext get _ctx => AdContext(
        platform: platform,
        useProductionAds: useProductionAds,
        canRequestAds: consent.canRequestAds,
        adFree: _adFree(),
        privateMode: privateMode,
      );

  /// Consent first, SDK second; the SDK is only initialised once UMP says
  /// requests are allowed.
  Future<void> start() async {
    if (!sdkAvailable) return;
    await consent.gather();
    await _initIfAllowed();
  }

  Future<void> _initIfAllowed() async {
    if (_initialized || !consent.canRequestAds) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    notifyListeners();
  }

  Future<void> showPrivacyOptions() async {
    await consent.showPrivacyOptions();
    await _initIfAllowed();
    notifyListeners();
  }

  void setPrivateMode(bool value) {
    if (privateMode == value) return;
    privateMode = value;
    if (value) {
      _interstitial?.dispose();
      _interstitial = null;
    }
    notifyListeners();
  }

  /// Ad unit for a banner slot, or null if nothing may be requested.
  String? bannerUnit(AdPlacementId placement) =>
      _initialized ? adUnitFor(_config(), placement, _ctx) : null;

  /// Preloads the (default-disabled) interstitial for a natural transition.
  void preloadInterstitial() {
    if (!_initialized || _interstitial != null) return;
    final unit = adUnitFor(_config(), AdPlacementId.tabsInterstitial, _ctx);
    if (unit == null) return;
    InterstitialAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Shows the interstitial only if every rule allows it. Returns whether
  /// one was shown.
  bool maybeShowInterstitial({
    required bool mediaPlaying,
    required bool fullscreen,
  }) {
    final ad = _interstitial;
    if (ad == null) return false;
    if (adUnitFor(_config(), AdPlacementId.tabsInterstitial, _ctx) == null) {
      return false;
    }
    final now = _clock();
    if (!_gate.canShow(_config().frequency, now,
        mediaPlaying: mediaPlaying, fullscreen: fullscreen)) {
      return false;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) => a.dispose(),
      onAdFailedToShowFullScreenContent: (a, _) => a.dispose(),
    );
    unawaited(ad.show());
    _interstitial = null;
    _gate.recordShown(now);
    return true;
  }

  @override
  void dispose() {
    consent.removeListener(notifyListeners);
    _interstitial?.dispose();
    super.dispose();
  }
}
