import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_providers.dart';
import '../../browser/browser_tab.dart';
import '../../core/url_input.dart';
import '../../core/url_safety.dart';
import '../../l10n/l10n.dart';

/// User-facing browser operations shared by the home page, address bar,
/// menus and lists.
class BrowserActions {
  BrowserActions(this.ref, this.context);
  final WidgetRef ref;
  final BuildContext context;

  /// Handles text typed into the address bar / search field.
  Future<void> submitInput(String text, {bool newTab = false}) async {
    final engine = ref.read(settingsProvider).searchEngine;
    switch (resolveInput(text, engine)) {
      case null:
        return;
      case NavigateTo(:final uri):
        open(uri, newTab: newTab);
      case SearchFor(:final uri):
        open(uri, newTab: newTab);
      case ExternalTarget(:final uri):
        await openExternalWithConfirm(uri);
    }
  }

  /// Opens [uri] in the current tab (or a new one).
  void open(Uri uri, {bool newTab = false, bool? private}) {
    if (classifyUrl(uri) != UrlDisposition.load) return;
    final tabs = ref.read(tabsProvider);
    var tab = tabs.current;
    if (newTab || tab == null) {
      tab = tabs.open(private: private ?? tab?.isPrivate ?? false);
    }
    loadInTab(tab, uri);
  }

  void loadInTab(BrowserTab tab, Uri uri) {
    final tabs = ref.read(tabsProvider);
    tab
      ..url = uri
      ..errorDescription = null;
    final c = tab.controller;
    if (c != null && tab.hasLiveWebView && tab.pendingLoad == null) {
      c.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
    } else {
      tab.pendingLoad = uri;
    }
    tabs.updated(tab, persist: true);
  }

  /// New tab page. For private tabs, checks that isolation is possible.
  Future<void> newTab({required bool private}) async {
    if (private && !await ensurePrivateSupported()) return;
    ref.read(tabsProvider).open(private: private);
  }

  Future<bool> ensurePrivateSupported() async {
    final ok = await ref.read(privateSessionProvider).isSupported();
    if (!ok && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(c.l10n.privateUnavailableTitle),
          content: Text(c.l10n.privateUnavailableBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(c.l10n.ok),
            ),
          ],
        ),
      );
    }
    return ok;
  }

  /// Asks before handing a non-web link to another app. Never automatic.
  Future<void> openExternalWithConfirm(Uri uri) async {
    if (classifyUrl(uri) == UrlDisposition.blocked) return;
    final scheme = uri.scheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.l10n.openExternalTitle),
        content: Text(c.l10n.openExternalBody(scheme)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.l10n.open),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication)
            .catchError((_) => false);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.noAppToOpen)));
    }
  }

  /// Opens the page in the system browser. Sessions/logins do NOT carry
  /// over; the UI says so.
  Future<void> openInSystemBrowser(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
  }

  Future<void> share(BrowserTab tab) async {
    final url = tab.url;
    if (url == null) return;
    await SharePlus.instance.share(ShareParams(uri: url, subject: tab.title));
  }

  Future<void> copyLink(BrowserTab tab) async {
    final url = tab.url;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.linkCopied)));
    }
  }

  Future<void> toggleBookmark(BrowserTab tab) async {
    final url = tab.url;
    if (url == null || tab.isPrivate) return;
    final repo = ref.read(bookmarksRepoProvider);
    final exists = await repo.isBookmarked(url.toString());
    if (exists) {
      await repo.removeByUrl(url.toString());
    } else {
      await repo.add(url.toString(), tab.title);
    }
    ref.read(dataRevisionProvider.notifier).state++;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(exists
              ? context.l10n.bookmarkRemoved
              : context.l10n.bookmarkAdded)));
    }
  }

  Future<void> toggleDesktopMode(BrowserTab tab) async {
    tab.desktopMode = !tab.desktopMode;
    final c = tab.controller;
    if (c != null) {
      await c.setSettings(
        settings: InAppWebViewSettings(
          preferredContentMode: tab.desktopMode
              ? UserPreferredContentMode.DESKTOP
              : UserPreferredContentMode.RECOMMENDED,
        ),
      );
      await c.reload();
    }
    ref.read(tabsProvider).updated(tab);
  }
}
