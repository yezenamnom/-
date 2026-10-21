import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_providers.dart';
import '../../blocking/blocking_service.dart';
import '../../blocking/webview_blocking.dart';
import '../../browser/browser_tab.dart';
import '../../core/url_safety.dart';
import '../../data/settings_controller.dart';
import '../../data/site_permissions_repository.dart';
import '../../downloads/downloads_service.dart';
import '../../media/media_policy.dart';
import '../../l10n/l10n.dart';
import 'browser_actions.dart';

/// Reports play/pause of page media so a tab playing audio is never frozen
/// and ads are never shown during playback. The handler accepts a boolean
/// only and exposes no capability to the page.
final _mediaStateScript = UserScript(
  groupName: 'vela-media',
  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  forMainFrameOnly: false,
  source: '''
(function () {
  function report() {
    try {
      var playing = false;
      var els = document.querySelectorAll('video, audio');
      for (var i = 0; i < els.length; i++) {
        if (!els[i].paused && !els[i].ended) { playing = true; break; }
      }
      window.flutter_inappwebview.callHandler('velaMedia', playing);
    } catch (e) {}
  }
  ['play', 'pause', 'ended', 'emptied'].forEach(function (t) {
    document.addEventListener(t, report, true);
  });
})();
''',
);

InAppWebViewSettings buildWebViewSettings({
  required BrowserTab tab,
  required SettingsController settings,
  required BlockingService blocking,
  required bool blockingActive,
}) {
  final isIos = !kIsWeb && Platform.isIOS;
  return InAppWebViewSettings(
    // Navigation & safety
    useShouldOverrideUrlLoading: true,
    useOnDownloadStart: true,
    supportMultipleWindows: true,
    javaScriptCanOpenWindowsAutomatically: !settings.blockPopups,
    javaScriptEnabled: settings.javascriptEnabled,
    allowFileAccess: false,
    allowContentAccess: false,
    allowFileAccessFromFileURLs: false,
    allowUniversalAccessFromFileURLs: false,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
    safeBrowsingEnabled: true,
    isFraudulentWebsiteWarningEnabled: true,
    // Private tabs: iOS non-persistent data store. On Android isolation is
    // done with a WebView profile (see PrivateSession); `incognito` there
    // would wipe the normal cookie jar, so it stays false.
    incognito: tab.isPrivate && isIos,
    thirdPartyCookiesEnabled: !tab.isPrivate && settings.thirdPartyCookies,
    saveFormData: !tab.isPrivate,
    cacheEnabled: true,
    // Media
    mediaPlaybackRequiresUserGesture: true,
    allowsInlineMediaPlayback: true,
    allowsPictureInPictureMediaPlayback: true,
    allowsAirPlayForMediaPlayback: true,
    iframeAllowFullscreen: true,
    // Display
    preferredContentMode: tab.desktopMode
        ? UserPreferredContentMode.DESKTOP
        : UserPreferredContentMode.RECOMMENDED,
    textZoom: (settings.textScale * 100).round(),
    pageZoom: settings.textScale,
    supportZoom: true,
    builtInZoomControls: true,
    displayZoomControls: false,
    isFindInteractionEnabled: false,
    // Blocking (network rules only; cosmetic via user script)
    contentBlockers: blockingActive ? toContentBlockers(blocking.list) : [],
  );
}

/// Hosts one tab's WebView. Kept alive across tab switches through
/// [BrowserTab.keepAlive]; rebuilt from [BrowserTab.pendingLoad] after
/// being frozen.
class TabWebView extends ConsumerStatefulWidget {
  const TabWebView({
    super.key,
    required this.tab,
    required this.findController,
    required this.onFullscreenChanged,
  });

  final BrowserTab tab;
  final FindInteractionController findController;
  final ValueChanged<bool> onFullscreenChanged;

  @override
  ConsumerState<TabWebView> createState() => _TabWebViewState();
}

class _TabWebViewState extends ConsumerState<TabWebView> {
  BrowserTab get tab => widget.tab;

  @override
  void initState() {
    super.initState();
    ref.read(blockingProvider).addListener(_onBlockingChanged);
  }

  @override
  void dispose() {
    ref.read(blockingProvider).removeListener(_onBlockingChanged);
    super.dispose();
  }

  void _notify({bool persist = false}) {
    if (!mounted) return;
    ref.read(tabsProvider).updated(tab, persist: persist);
  }

  bool _blockingActiveFor(Uri? url) =>
      ref.read(blockingProvider).isActiveFor(url?.host ?? '');

  Future<void> _onBlockingChanged() async {
    final c = tab.controller;
    if (c == null || !mounted) return;
    final blocking = ref.read(blockingProvider);
    await c.removeUserScriptsByGroupName(groupName: 'vela-cosmetic');
    if (blocking.enabled) {
      await c.addUserScript(
          userScript: cosmeticUserScript(blocking.list, blocking.exceptions));
    }
    await _applyBlockingFor(tab.url, force: true);
  }

  Future<void> _applyBlockingFor(Uri? url, {bool force = false}) async {
    final c = tab.controller;
    if (c == null) return;
    final active = _blockingActiveFor(url);
    if (!force && tab.blockingApplied == active) return;
    tab.blockingApplied = active;
    final blocking = ref.read(blockingProvider);
    await c.setSettings(
      settings: InAppWebViewSettings(
        contentBlockers: active ? toContentBlockers(blocking.list) : [],
      ),
    );
  }

  Future<void> _onCreated(InAppWebViewController c) async {
    tab.controller = c;
    c.addJavaScriptHandler(
      handlerName: 'velaMedia',
      callback: (args) {
        final playing = args.isNotEmpty && args.first == true;
        if (tab.mediaPlaying != playing) {
          tab.mediaPlaying = playing;
          _notify();
        }
        return null;
      },
    );
    if (tab.windowId != null) return; // content supplied by the opener
    // Only an explicit pending load navigates: a kept-alive WebView that is
    // re-attached after a tab switch must not reload.
    final pending = tab.pendingLoad;
    if (pending == null) return;
    if (tab.isPrivate) {
      final ok = await ref.read(privateSessionProvider).attach(tab.keepAlive!);
      if (!ok) {
        // Isolation could not be guaranteed: do not load anything.
        tab.errorDescription = mounted ? context.l10n.privateIsolationFailed : '';
        _notify();
        return;
      }
    }
    tab.pendingLoad = null;
    await c.loadUrl(urlRequest: URLRequest(url: WebUri.uri(pending)));
  }

  Future<NavigationActionPolicy> _shouldOverride(
    InAppWebViewController c,
    NavigationAction action,
  ) async {
    final url = action.request.url;
    if (url == null) return NavigationActionPolicy.CANCEL;
    switch (classifyUrl(url)) {
      case UrlDisposition.load:
        return NavigationActionPolicy.ALLOW;
      case UrlDisposition.external:
        // Only offer to leave the browser for a user-initiated main-frame
        // navigation; never auto-launch apps from scripts or iframes.
        final userInitiated = action.hasGesture ??
            action.navigationType == NavigationType.LINK_ACTIVATED;
        if (action.isForMainFrame && userInitiated && mounted) {
          unawaited(BrowserActions(ref, context).openExternalWithConfirm(url));
        }
        return NavigationActionPolicy.CANCEL;
      case UrlDisposition.blocked:
        return NavigationActionPolicy.CANCEL;
    }
  }

  void _onLoadStart(InAppWebViewController c, WebUri? url) {
    tab
      ..loading = true
      ..errorDescription = null;
    if (url != null && classifyUrl(url) == UrlDisposition.load) {
      tab
        ..url = url
        ..security = url.scheme == 'https'
            ? SecurityState.secure
            : (url.scheme == 'http' ? SecurityState.insecure : SecurityState.none);
    }
    unawaited(_applyBlockingFor(url));
    _notify();
  }

  Future<void> _onLoadStop(InAppWebViewController c, WebUri? url) async {
    tab
      ..loading = false
      ..progress = 1
      ..canGoBack = await c.canGoBack()
      ..canGoForward = await c.canGoForward();
    final title = await c.getTitle();
    if (title != null && title.isNotEmpty) tab.title = title;
    if (!tab.isPrivate && url != null && tab.errorDescription == null) {
      await ref.read(historyRepoProvider).record(url, tab.title);
    }
    _notify(persist: true);
  }

  Future<void> _onVisitedHistory(
      InAppWebViewController c, WebUri? url, bool? isReload) async {
    if (url != null && classifyUrl(url) == UrlDisposition.load) tab.url = url;
    tab
      ..canGoBack = await c.canGoBack()
      ..canGoForward = await c.canGoForward();
    _notify(persist: true);
  }

  void _onError(
      InAppWebViewController c, WebResourceRequest req, WebResourceError err) {
    if (req.isForMainFrame != true) return;
    if (err.type == WebResourceErrorType.CANCELLED) return;
    tab
      ..loading = false
      ..errorDescription = err.description;
    _notify();
  }

  Future<ServerTrustAuthResponse> _onServerTrust(
      InAppWebViewController c, URLAuthenticationChallenge challenge) async {
    // Certificate problems are never bypassed automatically (and the UI
    // offers no bypass either).
    tab
      ..security = SecurityState.certificateError
      ..loading = false
      ..errorDescription = mounted ? context.l10n.certificateError : 'TLS';
    _notify();
    return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);
  }

  Future<bool> _onCreateWindow(
      InAppWebViewController c, CreateWindowAction action) async {
    final url = action.request.url;
    final tabs = ref.read(tabsProvider);
    if (tab.isPrivate && Platform.isAndroid) {
      // Android private tabs need their profile attached before any load,
      // which the native window hand-over does not allow. Open the target
      // as a normal navigation in a new private tab instead.
      if (url != null && classifyUrl(url) == UrlDisposition.load && mounted) {
        BrowserActions(ref, context).open(url, newTab: true, private: true);
      }
      return false;
    }
    final child = tabs.open(private: tab.isPrivate)
      ..windowId = action.windowId
      ..url = (url != null && classifyUrl(url) == UrlDisposition.load)
          ? url
          : null;
    tabs.updated(child);
    return true;
  }

  void _onDownload(InAppWebViewController c, DownloadStartRequest req) async {
    final headers = <String, String>{
      if (req.userAgent != null) 'User-Agent': req.userAgent!,
    };
    // Cookies only for normal tabs and only for the download's own host.
    if (!tab.isPrivate) {
      final cookies = await CookieManager.instance().getCookies(url: req.url);
      if (cookies.isNotEmpty) {
        headers['Cookie'] =
            cookies.map((ck) => '${ck.name}=${ck.value}').join('; ');
      }
    }
    final item = await ref.read(downloadsProvider).start(DownloadRequest(
          url: req.url,
          suggestedFileName: req.suggestedFilename,
          mimeType: req.mimeType,
          contentDisposition: req.contentDisposition,
          headers: headers,
        ));
    if (!mounted || item == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.l10n.downloadStarted(item.fileName)),
    ));
  }

  Future<PermissionResponse> _onPermission(
      InAppWebViewController c, PermissionRequest req) async {
    final host = req.origin.host;
    final granted = <PermissionResourceType>[];
    for (final r in req.resources) {
      final kind = switch (r) {
        _ when r == PermissionResourceType.CAMERA => SitePermission.camera,
        _ when r == PermissionResourceType.MICROPHONE =>
          SitePermission.microphone,
        _ when r == PermissionResourceType.CAMERA_AND_MICROPHONE =>
          SitePermission.camera,
        _ when r == PermissionResourceType.GEOLOCATION =>
          SitePermission.location,
        _ => null,
      };
      if (kind == null) continue; // everything else is denied
      if (await _askSitePermission(host, kind)) {
        if (r == PermissionResourceType.CAMERA_AND_MICROPHONE &&
            !await _askSitePermission(host, SitePermission.microphone)) {
          continue;
        }
        granted.add(r);
      }
    }
    return PermissionResponse(
      resources: granted,
      action: granted.isEmpty
          ? PermissionResponseAction.DENY
          : PermissionResponseAction.GRANT,
    );
  }

  Future<GeolocationPermissionShowPromptResponse> _onGeolocation(
      InAppWebViewController c, String origin) async {
    final host = Uri.tryParse(origin)?.host ?? origin;
    final ok = await _askSitePermission(host, SitePermission.location);
    return GeolocationPermissionShowPromptResponse(
        origin: origin, allow: ok, retain: false);
  }

  /// Per-site decision (remembered only if the user chooses "always" and
  /// only for normal tabs), then the OS runtime permission.
  Future<bool> _askSitePermission(String host, SitePermission kind) async {
    final repo = ref.read(sitePermissionsProvider);
    var decision = tab.isPrivate ? null : await repo.get(host, kind);
    if (decision == null) {
      if (!mounted) return false;
      final answer = await showDialog<_PermAnswer>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text(c.l10n.permissionTitle(host)),
          content: Text(switch (kind) {
            SitePermission.camera => c.l10n.permissionCamera,
            SitePermission.microphone => c.l10n.permissionMicrophone,
            SitePermission.location => c.l10n.permissionLocation,
          }),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, _PermAnswer.deny),
                child: Text(c.l10n.deny)),
            if (!tab.isPrivate)
              TextButton(
                  onPressed: () => Navigator.pop(c, _PermAnswer.always),
                  child: Text(c.l10n.allowAlways)),
            FilledButton(
                onPressed: () => Navigator.pop(c, _PermAnswer.once),
                child: Text(c.l10n.allowOnce)),
          ],
        ),
      );
      if (answer == _PermAnswer.always) {
        await repo.set(host, kind, PermissionDecision.allow);
      }
      decision = (answer == _PermAnswer.once || answer == _PermAnswer.always)
          ? PermissionDecision.allow
          : PermissionDecision.deny;
    }
    if (decision != PermissionDecision.allow) return false;
    final osPermission = switch (kind) {
      SitePermission.camera => Permission.camera,
      SitePermission.microphone => Permission.microphone,
      SitePermission.location => Permission.locationWhenInUse,
    };
    return (await osPermission.request()).isGranted;
  }

  void _onFullscreen(bool value) {
    tab.fullscreen = value;
    widget.onFullscreenChanged(value);
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.read(settingsProvider);
    final blocking = ref.read(blockingProvider);
    final active = _blockingActiveFor(tab.pendingLoad ?? tab.url);
    tab.blockingApplied = active;
    return InAppWebView(
      key: ValueKey('webview-${tab.id}'),
      keepAlive: tab.keepAlive!,
      windowId: tab.windowId,
      findInteractionController: widget.findController,
      initialSettings: buildWebViewSettings(
        tab: tab,
        settings: settings,
        blocking: blocking,
        blockingActive: active,
      ),
      initialUserScripts: UnmodifiableListView([
        _mediaStateScript,
        if (blocking.enabled)
          cosmeticUserScript(blocking.list, blocking.exceptions),
      ]),
      onWebViewCreated: _onCreated,
      shouldOverrideUrlLoading: _shouldOverride,
      onLoadStart: _onLoadStart,
      onLoadStop: _onLoadStop,
      onProgressChanged: (c, p) {
        tab.progress = p / 100;
        _notify();
      },
      onTitleChanged: (c, title) {
        if (title == null || title.isEmpty) return;
        tab.title = title;
        if (!tab.isPrivate && tab.url != null) {
          unawaited(ref.read(historyRepoProvider).updateTitle(tab.url!, title));
        }
        _notify(persist: true);
      },
      onUpdateVisitedHistory: _onVisitedHistory,
      onReceivedError: _onError,
      onReceivedServerTrustAuthRequest: _onServerTrust,
      onCreateWindow: _onCreateWindow,
      onCloseWindow: (c) => ref.read(tabsProvider).close(tab.id),
      onDownloadStartRequest: _onDownload,
      onPermissionRequest: _onPermission,
      onGeolocationPermissionsShowPrompt: _onGeolocation,
      onEnterFullscreen: (c) => _onFullscreen(true),
      onExitFullscreen: (c) => _onFullscreen(false),
      onRenderProcessGone: (c, detail) {
        tab
          ..errorDescription = context.l10n.pageCrashed
          ..loading = false;
        _notify();
      },
      onWebContentProcessDidTerminate: (c) => c.reload(),
    );
  }
}

enum _PermAnswer { once, always, deny }

/// Called by the shell when the app goes to background/foreground.
Future<void> applyLifecycle(
  BrowserTab? tab,
  AppLifecycleState state, {
  required bool backgroundAudio,
}) async {
  final c = tab?.controller;
  if (c == null) return;
  final keepPlaying = backgroundAudio && backgroundPlaybackAllowed(tab?.url);
  if (state == AppLifecycleState.paused && !keepPlaying) {
    if (Platform.isAndroid) {
      await c.pause();
    } else {
      await c.pauseAllMediaPlayback();
    }
  } else if (state == AppLifecycleState.resumed && Platform.isAndroid) {
    await c.resume();
  }
}

/// System UI handling for fullscreen video.
Future<void> setImmersive(bool on) async {
  if (on) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  } else {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const []);
  }
}
