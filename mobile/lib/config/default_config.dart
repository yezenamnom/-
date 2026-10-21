import 'remote_config.dart';

/// Built-in configuration used on first launch, when the admin server is
/// unreachable, or when the remote config is invalid/expired. The browser
/// must be fully usable with only this.
RemoteConfig buildDefaultConfig() => RemoteConfig(
      configVersion: 0,
      issuedAt: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(9999, 1, 1),
      minAppVersion: null,
      maxAppVersion: null,
      shortcuts: const [
        RemoteShortcut(
          id: 'youtube',
          title: {'en': 'YouTube', 'ar': 'يوتيوب', 'de': 'YouTube'},
          url: 'https://m.youtube.com/',
          iconKey: 'youtube',
          iconAssetId: null,
          color: '#E53935',
          order: 0,
        ),
        RemoteShortcut(
          id: 'twitch',
          title: {'en': 'Twitch', 'ar': 'تويتش', 'de': 'Twitch'},
          url: 'https://m.twitch.tv/',
          iconKey: 'twitch',
          iconAssetId: null,
          color: '#7E57C2',
          order: 1,
        ),
        RemoteShortcut(
          id: 'tiktok',
          title: {'en': 'TikTok', 'ar': 'تيك توك', 'de': 'TikTok'},
          url: 'https://www.tiktok.com/',
          iconKey: 'tiktok',
          iconAssetId: null,
          color: '#212121',
          order: 2,
        ),
        RemoteShortcut(
          id: 'rumble',
          title: {'en': 'Rumble', 'ar': 'رامبل', 'de': 'Rumble'},
          url: 'https://rumble.com/',
          iconKey: 'rumble',
          iconAssetId: null,
          color: '#43A047',
          order: 3,
        ),
      ],
      ads: const AdsConfig(
        enabled: true,
        placements: {
          AdPlacementId.homeBanner: AdPlacementConfig(
            id: AdPlacementId.homeBanner,
            enabled: true,
            adUnitIdAndroid: null,
            adUnitIdIos: null,
          ),
          AdPlacementId.downloadsBanner: AdPlacementConfig(
            id: AdPlacementId.downloadsBanner,
            enabled: true,
            adUnitIdAndroid: null,
            adUnitIdIos: null,
          ),
          AdPlacementId.tabsInterstitial: AdPlacementConfig(
            id: AdPlacementId.tabsInterstitial,
            enabled: false,
            adUnitIdAndroid: null,
            adUnitIdIos: null,
          ),
        },
        frequency: AdFrequency(
          interstitialMinIntervalSec: 600,
          interstitialMaxPerSession: 1,
        ),
      ),
      blocking: const BlockingConfig(
        enabledByDefault: true,
        listVersion: null,
        listPath: null,
        listSha256: null,
        ruleCount: null,
      ),
      content: const ContentConfig(),
      notices: const [],
    );
