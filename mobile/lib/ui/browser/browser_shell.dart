import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// Exposes InAppWebViewKeepAlive.id (the key flutter_inappwebview's native
// side uses for kept-alive WebViews).
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart'
    show InternalInAppWebViewKeepAlive;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../browser/browser_tab.dart';
import '../../l10n/l10n.dart';
import '../../media/media_policy.dart';
import '../home/home_page.dart';
import '../tabs/tabs_screen.dart';
import '../theme.dart';
import 'address_bar.dart';
import 'browser_actions.dart';
import 'browser_menu.dart';
import 'find_bar.dart';
import 'tab_webview.dart';

class BrowserShell extends ConsumerStatefulWidget {
  const BrowserShell({super.key});

  @override
  ConsumerState<BrowserShell> createState() => _BrowserShellState();
}

class _BrowserShellState extends ConsumerState<BrowserShell>
    with WidgetsBindingObserver {
  /// Created on first WebView use (needs the platform implementation).
  late final FindInteractionController _find = FindInteractionController(
    onFindResultReceived: (c, active, total, done) {
      if (done) {
        _findStatus.value = total == 0 ? '0/0' : '${active + 1}/$total';
      }
    },
  );
  final ValueNotifier<String> _findStatus = ValueNotifier('');
  bool _findOpen = false;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _findStatus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final tabs = ref.read(tabsProvider);
    unawaited(applyLifecycle(tabs.current, state,
        backgroundAudio: ref.read(settingsProvider).backgroundAudio));
    if (state == AppLifecycleState.paused) unawaited(tabs.saveNow());
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(configProvider).refresh());
    }
  }

  void _onFullscreen(bool value) {
    setState(() => _fullscreen = value);
    unawaited(setImmersive(value));
    final pip = ref.read(pipProvider);
    final url = ref.read(tabsProvider).current?.url;
    unawaited(pip.setAuto(value &&
        ref.read(settingsProvider).autoPip &&
        backgroundPlaybackAllowed(url)));
  }

  Future<void> _openTabs() async {
    final tabs = ref.read(tabsProvider);
    final cur = tabs.current;
    if (cur != null && !cur.isPrivate && cur.controller != null && !cur.isHome) {
      try {
        cur.thumbnail = await cur.controller!.takeScreenshot(
          screenshotConfiguration: ScreenshotConfiguration(
            compressFormat: CompressFormat.JPEG,
            quality: 40,
            snapshotWidth: 360,
          ),
        );
      } on Exception {
        cur.thumbnail = null;
      }
    }
    final ads = ref.read(adsProvider)..preloadInterstitial();
    if (!mounted) return;
    final selected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TabsScreen()),
    );
    if (selected == true) {
      ads.maybeShowInterstitial(
        mediaPlaying: tabs.tabs.any((t) => t.mediaPlaying),
        fullscreen: _fullscreen,
      );
    }
  }

  void _closeFind() {
    setState(() => _findOpen = false);
    unawaited(_find.clearMatches());
    _findStatus.value = '';
  }

  Future<bool> _handleBack(BrowserTab? tab) async {
    if (_findOpen) {
      _closeFind();
      return true;
    }
    if (tab == null) return false;
    if (tab.errorDescription != null && tab.canGoBack) {
      tab.errorDescription = null;
    }
    if (!tab.isHome && tab.canGoBack && tab.controller != null) {
      await tab.controller!.goBack();
      return true;
    }
    if (!tab.isHome) {
      tab.url = null;
      ref.read(tabsProvider).updated(tab, persist: true);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(tabsProvider);
    final pip = ref.watch(pipProvider);
    final tab = tabs.current;
    final private = tab?.isPrivate ?? false;
    final scheme = Theme.of(context).colorScheme;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(adsProvider).setPrivateMode(private);
    });

    final showWeb = tab != null && !tab.isHome;
    // The keep-alive handle identifies the native WebView; a frozen tab
    // gets a new one, which (via the key) builds a fresh WebView.
    if (showWeb) tab.keepAlive ??= InAppWebViewKeepAlive();
    final webview = showWeb
        ? TabWebView(
            key: ValueKey('tab-${tab.id}-${tab.keepAlive!.id}'),
            tab: tab,
            findController: _find,
            onFullscreenChanged: _onFullscreen,
          )
        : null;

    if (pip.inPip && webview != null) {
      return Scaffold(backgroundColor: Colors.black, body: webview);
    }

    final body = Column(children: [
      if (showWeb && !_fullscreen) ...[
        AddressBar(tab: tab),
        if (tab.loading)
          LinearProgressIndicator(value: tab.progress, minHeight: 2)
        else
          const SizedBox(height: 2),
      ],
      if (_findOpen && showWeb && !_fullscreen)
        FindBar(
          controller: _find,
          status: _findStatus,
          onClose: _closeFind,
        ),
      Expanded(
        child: Stack(children: [
          if (webview != null)
            Positioned.fill(child: webview)
          else
            Positioned.fill(child: HomePage(private: private)),
          if (showWeb && tab.errorDescription != null)
            Positioned.fill(child: _ErrorView(tab: tab)),
        ]),
      ),
    ]);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final handled = await _handleBack(tab);
        if (!handled && context.mounted) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: private
            ? AppTheme.privateBackground(Theme.of(context).brightness)
            : scheme.surface,
        body: SafeArea(top: !_fullscreen, bottom: false, child: body),
        bottomNavigationBar: _fullscreen
            ? null
            : _BottomBar(
                tab: tab,
                tabCount: private ? tabs.privateTabs.length : tabs.normalTabs.length,
                onTabs: _openTabs,
                onFind: () => setState(() => _findOpen = true),
              ),
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.tab,
    required this.tabCount,
    required this.onTabs,
    required this.onFind,
  });

  final BrowserTab? tab;
  final int tabCount;
  final VoidCallback onTabs;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final t = tab;
    final browsing = t != null && !t.isHome;
    final actions = BrowserActions(ref, context);
    final private = t?.isPrivate ?? false;

    final tabsButton = IconButton(
      tooltip: l.tabs,
      onPressed: onTabs,
      icon: _TabCountIcon(count: tabCount),
    );
    final menuButton = IconButton(
      tooltip: l.menu,
      icon: const Icon(Icons.more_vert),
      onPressed: () => showBrowserMenu(context, ref, onFind: onFind),
    );

    return BottomAppBar(
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: browsing
              ? [
                  IconButton(
                    tooltip: l.back,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: t.canGoBack ? () => t.controller?.goBack() : null,
                  ),
                  IconButton(
                    tooltip: l.forward,
                    icon: const Icon(Icons.arrow_forward),
                    onPressed:
                        t.canGoForward ? () => t.controller?.goForward() : null,
                  ),
                  IconButton(
                    tooltip: l.home,
                    icon: const Icon(Icons.home_outlined),
                    onPressed: () {
                      t.url = null;
                      ref.read(tabsProvider).updated(t, persist: true);
                    },
                  ),
                  tabsButton,
                  menuButton,
                ]
              : [
                  IconButton(
                    tooltip: private ? l.exitPrivate : l.newPrivateTab,
                    icon: Icon(private
                        ? Icons.no_accounts_outlined
                        : Icons.privacy_tip_outlined),
                    onPressed: () async {
                      if (private) {
                        await ref.read(tabsProvider).closeAll(private: true);
                      } else {
                        await actions.newTab(private: true);
                      }
                    },
                  ),
                  tabsButton,
                  menuButton,
                ],
        ),
      ),
    );
  }
}

class _TabCountIcon extends StatelessWidget {
  const _TabCountIcon({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color ?? Colors.black, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        count > 99 ? ':D' : '$count',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: color),
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.tab});
  final BrowserTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cert = tab.security == SecurityState.certificateError;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(cert ? Icons.gpp_bad_outlined : Icons.cloud_off_outlined,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(cert ? l.certificateErrorTitle : l.pageLoadFailed,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(tab.errorDescription ?? '', textAlign: TextAlign.center),
            if (tab.url != null) ...[
              const SizedBox(height: 8),
              Text(tab.url!.host,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 24),
            Wrap(spacing: 12, children: [
              if (tab.canGoBack)
                OutlinedButton(
                  onPressed: () {
                    tab.errorDescription = null;
                    tab.controller?.goBack();
                    ref.read(tabsProvider).updated(tab);
                  },
                  child: Text(l.back),
                ),
              if (!cert)
                FilledButton(
                  onPressed: () {
                    tab.errorDescription = null;
                    final url = tab.url;
                    if (url != null) BrowserActions(ref, context).loadInTab(tab, url);
                  },
                  child: Text(l.retry),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}
