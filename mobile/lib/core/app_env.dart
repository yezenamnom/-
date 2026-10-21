import 'package:flutter/foundation.dart';

/// Build-time environment. Values come from `--dart-define` (see
/// mobile/env/*.example.json and README). Nothing here is a secret: the
/// config public key is public by design.
class AppEnv {
  static const flavor = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Base URL of the admin/config server, e.g. https://config.example.com.
  /// Empty means remote config is disabled and built-in defaults are used.
  static const configBaseUrl = String.fromEnvironment('CONFIG_BASE_URL');

  /// Raw Ed25519 public key (base64url) used to verify remote config.
  static const configPublicKey = String.fromEnvironment('CONFIG_PUBLIC_KEY');

  /// Production ad units are only ever used in release builds of the
  /// production flavor. Everything else is forced to Google test ads.
  static bool get useProductionAds => kReleaseMode && flavor == 'production';

  /// Allow plain-http config server for local development only.
  static bool get allowInsecureConfigServer => !kReleaseMode && flavor == 'dev';
}
