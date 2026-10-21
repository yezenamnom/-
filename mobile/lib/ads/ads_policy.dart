import '../config/remote_config.dart';

enum AdPlatform { android, ios }

/// Google's official sample ad units
/// (https://developers.google.com/admob/flutter/test-ads). Used for every
/// non-production build regardless of remote config.
class TestAdUnits {
  static const androidBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const iosBanner = 'ca-app-pub-3940256099942544/2435281174';
  static const androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const iosInterstitial = 'ca-app-pub-3940256099942544/4411468910';

  static String forPlacement(AdPlacementId id, AdPlatform platform) {
    final interstitial = id == AdPlacementId.tabsInterstitial;
    return switch ((platform, interstitial)) {
      (AdPlatform.android, false) => androidBanner,
      (AdPlatform.ios, false) => iosBanner,
      (AdPlatform.android, true) => androidInterstitial,
      (AdPlatform.ios, true) => iosInterstitial,
    };
  }
}

/// Everything that decides whether an ad request may be made at all.
class AdContext {
  const AdContext({
    required this.platform,
    required this.useProductionAds,
    required this.canRequestAds,
    required this.adFree,
    required this.privateMode,
  });

  final AdPlatform platform;
  final bool useProductionAds;

  /// From Google UMP `ConsentInformation.canRequestAds()`; never a local
  /// stand-in.
  final bool canRequestAds;

  /// The user has a verified ad-free entitlement.
  final bool adFree;

  /// A private tab is in the foreground: no ad requests at all.
  final bool privateMode;
}

/// Returns the ad unit to request for [placement], or null if no request
/// may be made.
String? adUnitFor(AdsConfig ads, AdPlacementId placement, AdContext ctx) {
  if (!ads.enabled || ctx.adFree || ctx.privateMode || !ctx.canRequestAds) {
    return null;
  }
  final p = ads.placements[placement];
  if (p == null || !p.enabled) return null;
  if (!ctx.useProductionAds) {
    return TestAdUnits.forPlacement(placement, ctx.platform);
  }
  return ctx.platform == AdPlatform.android ? p.adUnitIdAndroid : p.adUnitIdIos;
}

/// Local frequency cap for interstitials. The remote config can only make
/// it stricter than the compiled floor (see [AdFrequency.clamped]).
class InterstitialGate {
  InterstitialGate({required DateTime sessionStart}) : _sessionStart = sessionStart;

  /// No interstitial in the first minutes of a session.
  static const warmUp = Duration(minutes: 3);

  final DateTime _sessionStart;
  DateTime? _lastShown;
  int _shownThisSession = 0;

  int get shownThisSession => _shownThisSession;

  bool canShow(
    AdFrequency f,
    DateTime now, {
    required bool mediaPlaying,
    required bool fullscreen,
  }) {
    if (mediaPlaying || fullscreen) return false;
    if (_shownThisSession >= f.interstitialMaxPerSession) return false;
    if (now.difference(_sessionStart) < warmUp) return false;
    final last = _lastShown;
    if (last != null &&
        now.difference(last).inSeconds < f.interstitialMinIntervalSec) {
      return false;
    }
    return true;
  }

  void recordShown(DateTime now) {
    _lastShown = now;
    _shownThisSession++;
  }
}
