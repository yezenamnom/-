import 'package:flutter_test/flutter_test.dart';
import 'package:vela_browser/ads/ads_policy.dart';
import 'package:vela_browser/config/default_config.dart';
import 'package:vela_browser/config/remote_config.dart';

void main() {
  const prodIds = AdsConfig(
    enabled: true,
    placements: {
      AdPlacementId.homeBanner: AdPlacementConfig(
        id: AdPlacementId.homeBanner,
        enabled: true,
        adUnitIdAndroid: 'ca-app-pub-1111111111111111/2222222222',
        adUnitIdIos: 'ca-app-pub-1111111111111111/3333333333',
      ),
      AdPlacementId.tabsInterstitial: AdPlacementConfig(
        id: AdPlacementId.tabsInterstitial,
        enabled: false,
        adUnitIdAndroid: 'ca-app-pub-1111111111111111/4444444444',
        adUnitIdIos: null,
      ),
    },
    frequency: AdFrequency(
        interstitialMinIntervalSec: 600, interstitialMaxPerSession: 1),
  );

  AdContext ctx({
    bool prod = false,
    bool consent = true,
    bool adFree = false,
    bool private = false,
    AdPlatform platform = AdPlatform.android,
  }) =>
      AdContext(
        platform: platform,
        useProductionAds: prod,
        canRequestAds: consent,
        adFree: adFree,
        privateMode: private,
      );

  test('non-production builds always use Google test units', () {
    expect(adUnitFor(prodIds, AdPlacementId.homeBanner, ctx()),
        TestAdUnits.androidBanner);
    expect(
        adUnitFor(prodIds, AdPlacementId.homeBanner,
            ctx(platform: AdPlatform.ios)),
        TestAdUnits.iosBanner);
    expect(adUnitFor(buildDefaultConfig().ads, AdPlacementId.homeBanner, ctx()),
        TestAdUnits.androidBanner);
  });

  test('production uses configured unit per platform', () {
    expect(adUnitFor(prodIds, AdPlacementId.homeBanner, ctx(prod: true)),
        'ca-app-pub-1111111111111111/2222222222');
    expect(
        adUnitFor(prodIds, AdPlacementId.homeBanner,
            ctx(prod: true, platform: AdPlatform.ios)),
        'ca-app-pub-1111111111111111/3333333333');
    expect(
        adUnitFor(buildDefaultConfig().ads, AdPlacementId.homeBanner,
            ctx(prod: true)),
        isNull,
        reason: 'no production id configured -> no request');
  });

  test('no request without consent, in private mode, or when ad-free', () {
    expect(adUnitFor(prodIds, AdPlacementId.homeBanner, ctx(consent: false)),
        isNull);
    expect(adUnitFor(prodIds, AdPlacementId.homeBanner, ctx(private: true)),
        isNull);
    expect(adUnitFor(prodIds, AdPlacementId.homeBanner, ctx(adFree: true)),
        isNull);
  });

  test('disabled placement, missing placement, global switch', () {
    expect(adUnitFor(prodIds, AdPlacementId.tabsInterstitial, ctx()), isNull);
    expect(adUnitFor(prodIds, AdPlacementId.downloadsBanner, ctx()), isNull);
    const off = AdsConfig(
        enabled: false,
        placements: {},
        frequency: AdFrequency(
            interstitialMinIntervalSec: 600, interstitialMaxPerSession: 1));
    expect(adUnitFor(off, AdPlacementId.homeBanner, ctx()), isNull);
  });

  test('interstitial frequency gate', () {
    final start = DateTime(2026, 1, 1, 12);
    final gate = InterstitialGate(sessionStart: start);
    final f = AdFrequency.clamped(10, 2); // clamped to 300s, 2/session
    expect(f.interstitialMinIntervalSec, 300);

    bool can(DateTime t, {bool media = false, bool fs = false}) =>
        gate.canShow(f, t, mediaPlaying: media, fullscreen: fs);

    expect(can(start.add(const Duration(minutes: 1))), isFalse,
        reason: 'warm-up');
    final t1 = start.add(const Duration(minutes: 5));
    expect(can(t1, media: true), isFalse);
    expect(can(t1, fs: true), isFalse);
    expect(can(t1), isTrue);
    gate.recordShown(t1);
    expect(can(t1.add(const Duration(seconds: 299))), isFalse);
    final t2 = t1.add(const Duration(seconds: 300));
    expect(can(t2), isTrue);
    gate.recordShown(t2);
    expect(can(t2.add(const Duration(hours: 1))), isFalse,
        reason: 'session cap');
  });

  test('clamp cannot be bypassed by remote values', () {
    final f = AdFrequency.clamped(-5, 99);
    expect(f.interstitialMinIntervalSec, AdFrequency.minIntervalFloorSec);
    expect(f.interstitialMaxPerSession, AdFrequency.maxPerSessionCeiling);
  });
}
