import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// Exposes InAppWebViewKeepAlive.id (the key flutter_inappwebview's native
// side uses for kept-alive WebViews).
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart'
    show InternalInAppWebViewKeepAlive;

/// Isolation of private tabs from normal browsing data.
///
/// - iOS: each private WebView uses `WKWebsiteDataStore.nonPersistent()`
///   (flutter_inappwebview `incognito: true`). Nothing is written to disk and
///   it disappears with the WebView.
/// - Android: flutter_inappwebview's `incognito` wipes the *global* cookie
///   jar and does not isolate anything, so it is NOT used. Instead every
///   private session gets its own AndroidX WebView profile (separate cookies,
///   storage, cache), attached natively before the first load and deleted
///   when the session ends. Devices whose System WebView lacks
///   MULTI_PROFILE support cannot open private tabs at all; we refuse rather
///   than pretend.
class PrivateSession {
  PrivateSession({required this.isAndroid, MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('vela/webview_profile');

  static const profilePrefix = 'vela-private-';

  final bool isAndroid;
  final MethodChannel _channel;
  String? _profile;
  bool? _supported;

  Future<bool> isSupported() async {
    if (!isAndroid) return true;
    return _supported ??=
        await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  String get _profileName =>
      _profile ??= '$profilePrefix${DateTime.now().millisecondsSinceEpoch}';

  /// Must be called after the WebView exists and before it loads anything.
  /// Returns false if isolation could not be guaranteed; the caller must
  /// then not load the page.
  Future<bool> attach(InAppWebViewKeepAlive keepAlive) async {
    if (!isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'attach',
            {'keepAliveId': keepAlive.id, 'profile': _profileName},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Destroys the private session's data. WebViews must already be disposed.
  Future<void> end() async {
    _profile = null;
    if (!isAndroid) return;
    // WebView teardown is asynchronous; retry briefly. Anything left is
    // removed by [cleanupLeftovers] on the next launch, and a new session
    // always uses a fresh profile name, so nothing carries over.
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      try {
        await _channel.invokeMethod<int>(
            'deleteProfiles', {'prefix': profilePrefix});
        return;
      } on PlatformException {
        continue;
      }
    }
  }

  Future<void> cleanupLeftovers() async {
    if (!isAndroid) return;
    try {
      await _channel
          .invokeMethod<int>('deleteProfiles', {'prefix': profilePrefix});
    } on PlatformException {
      // Ignore: retried next launch.
    } on MissingPluginException {
      // Widget tests / unsupported host.
    }
  }
}
