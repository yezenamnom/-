import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

enum SecurityState { none, secure, insecure, certificateError }

/// Runtime state of one tab. The WebView itself is created lazily by the UI
/// and kept alive across tab switches via [keepAlive]; a frozen tab has its
/// native WebView released and is reloaded from [url] when shown again.
class BrowserTab {
  BrowserTab({
    required this.id,
    required this.isPrivate,
    this.url,
    this.title = '',
    DateTime? lastActive,
  }) : lastActive = lastActive ?? DateTime.now();

  final String id;
  final bool isPrivate;

  /// Null = new-tab page (home).
  Uri? url;
  String title;
  DateTime lastActive;

  double progress = 1;
  bool loading = false;
  bool canGoBack = false;
  bool canGoForward = false;
  SecurityState security = SecurityState.none;
  bool desktopMode = false;

  /// A page reported media playing (play/pause events). Never frozen while
  /// true so background audio of the active tab is not killed.
  bool mediaPlaying = false;

  /// Load error shown in place of the page, with retry.
  String? errorDescription;

  /// Normal tabs only; private tab previews are never captured.
  Uint8List? thumbnail;

  InAppWebViewKeepAlive? keepAlive;
  InAppWebViewController? controller;
  bool frozen = false;

  /// Whether native content blockers are currently applied to this WebView
  /// (they are switched off for sites the user excepted).
  bool? blockingApplied;

  /// Set when the page opened this tab via window.open/target=_blank and the
  /// native layer is waiting to hand over the new WebView.
  int? windowId;

  bool fullscreen = false;

  /// Pending URL to load once the WebView exists (and, for private tabs on
  /// Android, once its isolated profile is attached).
  Uri? pendingLoad;

  bool get isHome => url == null;
  bool get hasLiveWebView => keepAlive != null && !frozen;
}
