import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../l10n/l10n.dart';
import '../../media/media_policy.dart';
import '../bookmarks/bookmarks_page.dart';
import '../downloads/downloads_page.dart';
import '../history/history_page.dart';
import '../report/report_page.dart';
import '../settings/settings_page.dart';
import 'browser_actions.dart';
import 'search_screen.dart';

Future<void> showBrowserMenu(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback onFind,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => _BrowserMenu(parent: context, onFind: onFind),
  );
}

void pushPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

class _BrowserMenu extends ConsumerWidget {
  const _BrowserMenu({required this.parent, required this.onFind});

  /// Context below the sheet, used after the sheet is closed.
  final BuildContext parent;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tab = ref.watch(tabsProvider).current;
    final browsing = tab != null && !tab.isHome;
    final actions = BrowserActions(ref, parent);
    final pip = ref.watch(pipProvider);

    void run(VoidCallback f) {
      Navigator.of(context).pop();
      f();
    }

    Widget item(IconData icon, String label, VoidCallback onTap,
            {bool enabled = true}) =>
        _MenuItem(
            icon: icon,
            label: label,
            onTap: enabled ? () => run(onTap) : null);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Wrap(
          alignment: WrapAlignment.start,
          children: [
            item(Icons.add, l.newTab, () async {
              await actions.newTab(private: false);
              if (parent.mounted) await openSearchScreen(parent, ref);
            }),
            item(Icons.privacy_tip_outlined, l.newPrivateTab,
                () => actions.newTab(private: true)),
            if (browsing && !tab.isPrivate)
              item(Icons.star_border, l.bookmarkThisPage,
                  () => actions.toggleBookmark(tab)),
            if (browsing) item(Icons.share_outlined, l.share, () => actions.share(tab)),
            if (browsing) item(Icons.link, l.copyLink, () => actions.copyLink(tab)),
            if (browsing) item(Icons.search, l.findInPage, onFind),
            if (browsing)
              item(
                  tab.desktopMode
                      ? Icons.phone_android
                      : Icons.desktop_windows_outlined,
                  tab.desktopMode ? l.mobileSite : l.desktopSite,
                  () => actions.toggleDesktopMode(tab)),
            if (browsing)
              item(Icons.open_in_new, l.openInSystemBrowser, () async {
                await actions.openInSystemBrowser(tab.url!);
              }),
            if (browsing &&
                tab.fullscreen &&
                pip.isAndroid &&
                backgroundPlaybackAllowed(tab.url))
              item(Icons.picture_in_picture_alt_outlined, l.pictureInPicture,
                  () => ref.read(pipProvider).enter()),
            item(Icons.bookmarks_outlined, l.bookmarks,
                () => pushPage(parent, const BookmarksPage())),
            item(Icons.history, l.history,
                () => pushPage(parent, const HistoryPage())),
            item(Icons.download_outlined, l.downloads,
                () => pushPage(parent, const DownloadsPage())),
            item(Icons.flag_outlined, l.reportProblem,
                () => pushPage(parent, ReportPage(siteHost: tab?.url?.host))),
            item(Icons.settings_outlined, l.settings,
                () => pushPage(parent, const SettingsPage())),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 24) / 4;
    return SizedBox(
      width: width.clamp(72, 120),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}
