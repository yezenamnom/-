import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ads/banner_slot.dart';
import '../../app_providers.dart';
import '../../config/remote_config.dart';
import '../../core/version.dart';
import '../../data/shortcuts_repository.dart';
import '../../l10n/l10n.dart';
import '../bookmarks/bookmarks_page.dart';
import '../browser/browser_actions.dart';
import '../browser/browser_menu.dart';
import '../browser/search_screen.dart';
import '../downloads/downloads_page.dart';
import '../history/history_page.dart';
import '../settings/settings_page.dart';
import 'shortcut_editor.dart';
import 'shortcut_icon.dart';

/// New-tab page: search field, site shortcuts, quick actions.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.private});
  final bool private;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _rev = 0;

  void _reload() => setState(() => _rev++);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final config = ref.watch(configProvider).config;
    final lang = Localizations.localeOf(context).languageCode;
    final repo = ref.read(shortcutsRepoProvider);
    final scheme = Theme.of(context).colorScheme;
    final onBg = widget.private ? Colors.white : scheme.onSurface;

    final content = LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 600;
      return CustomScrollView(slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
              horizontal: wide ? constraints.maxWidth * 0.15 : 16),
          sliver: SliverList.list(children: [
            SizedBox(height: constraints.maxHeight * 0.08),
            Center(
              child: Text(
                widget.private ? l.privateTab : l.appName,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: onBg, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
            _SearchField(private: widget.private),
            const SizedBox(height: 16),
            for (final n in config.notices)
              if (versionInRange(
                  _appVersion(ref), n.minAppVersion, n.maxAppVersion))
                _NoticeCard(text: localized(n.message, lang)),
            if (widget.private)
              _PrivateInfo(color: onBg)
            else ...[
              FutureBuilder<List<ShortcutItem>>(
                key: ValueKey(_rev),
                future: repo.loadUserItems(),
                builder: (context, snap) {
                  final view = computeShortcutsView(
                    remote: config.shortcuts,
                    customized: repo.customized,
                    userItems: snap.data ?? const [],
                    seenRemoteIds: repo.seenRemoteIds,
                    dismissedRemoteIds: repo.dismissedRemoteIds,
                    languageCode: lang,
                  );
                  return _Shortcuts(
                    view: view,
                    remote: config.shortcuts,
                    onChanged: _reload,
                  );
                },
              ),
              const SizedBox(height: 16),
              _QuickActions(),
            ],
            const SizedBox(height: 24),
          ]),
        ),
      ]);
    });
    // The banner sits below the content, above the bottom bar, never over
    // web content or navigation controls; it takes no space until loaded.
    return Column(children: [
      Expanded(child: content),
      if (!widget.private)
        const BannerSlot(placement: AdPlacementId.homeBanner),
    ]);
  }

  String _appVersion(WidgetRef ref) => ref.read(configProvider).appVersion;
}

class _SearchField extends ConsumerWidget {
  const _SearchField({required this.private});
  final bool private;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final engine = ref.watch(settingsProvider).searchEngine;
    return Semantics(
      button: true,
      label: l.searchOrType,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () => openSearchScreen(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(children: [
              const Icon(Icons.search),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.searchWith(engine.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Shortcuts extends ConsumerWidget {
  const _Shortcuts({
    required this.view,
    required this.remote,
    required this.onChanged,
  });

  final ShortcutsView view;
  final List<RemoteShortcut> remote;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.read(shortcutsRepoProvider);
    final lang = Localizations.localeOf(context).languageCode;

    Future<void> edit(List<ShortcutItem> Function(List<ShortcutItem>) f) async {
      await repo.edit(view.items, remote, f);
      onChanged();
    }

    Future<void> onLongPress(ShortcutItem s) async {
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text(s.title),
              subtitle: Text(s.url, textDirection: TextDirection.ltr),
            ),
            ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(c.l10n.edit),
                onTap: () => Navigator.pop(c, 'edit')),
            ListTile(
                leading: const Icon(Icons.arrow_back),
                title: Text(c.l10n.moveEarlier),
                onTap: () => Navigator.pop(c, 'up')),
            ListTile(
                leading: const Icon(Icons.arrow_forward),
                title: Text(c.l10n.moveLater),
                onTap: () => Navigator.pop(c, 'down')),
            ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(c.l10n.delete),
                onTap: () => Navigator.pop(c, 'delete')),
          ]),
        ),
      );
      if (!context.mounted) return;
      switch (action) {
        case 'edit':
          final edited = await showShortcutEditor(context, existing: s);
          if (edited != null) {
            await edit((items) => [
                  for (final i in items) i.id == s.id ? edited : i,
                ]);
          }
        case 'up' || 'down':
          await edit((items) {
            final i = items.indexWhere((e) => e.id == s.id);
            final j = action == 'up' ? i - 1 : i + 1;
            if (i < 0 || j < 0 || j >= items.length) return items;
            final tmp = items[i];
            items[i] = items[j];
            items[j] = tmp;
            return items;
          });
        case 'delete':
          await edit((items) => items..removeWhere((e) => e.id == s.id));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (view.suggestions.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.newSuggestedShortcuts,
                      style: Theme.of(context).textTheme.titleSmall),
                  for (final r in view.suggestions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ShortcutIcon(
                          title: localized(r.title, lang),
                          iconKey: r.iconKey,
                          color: r.color,
                          size: 36),
                      title: Text(localized(r.title, lang)),
                      trailing: Wrap(children: [
                        IconButton(
                          tooltip: l.dismiss,
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await repo.dismissSuggestion(r.id);
                            onChanged();
                          },
                        ),
                        IconButton(
                          tooltip: l.add,
                          icon: const Icon(Icons.add),
                          onPressed: () async {
                            await edit((items) =>
                                items..add(fromRemote(r, lang)));
                            await repo.markSuggestionsSeen([r.id]);
                            onChanged();
                          },
                        ),
                      ]),
                    ),
                ]),
          ),
        ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        runSpacing: 12,
        children: [
          for (final s in view.items)
            _ShortcutTile(
              title: s.title,
              iconKey: s.iconKey,
              color: s.color,
              onTap: () =>
                  BrowserActions(ref, context).open(Uri.parse(s.url)),
              onLongPress: () => onLongPress(s),
            ),
          if (view.items.length < ShortcutsRepository.maxShortcuts)
            _ShortcutTile(
              title: l.addShortcut,
              icon: Icons.add,
              onTap: () async {
                final created = await showShortcutEditor(context);
                if (created != null) await edit((items) => items..add(created));
              },
            ),
        ],
      ),
    ]);
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.title,
    this.iconKey,
    this.color,
    this.icon,
    required this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? iconKey;
  final String? color;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            icon != null
                ? CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(icon))
                : ShortcutIcon(title: title, iconKey: iconKey, color: color),
            const SizedBox(height: 6),
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget action(IconData icon, String label, Widget page) => Expanded(
          child: _ShortcutTile(
            title: label,
            icon: icon,
            onTap: () => pushPage(context, page),
          ),
        );
    return Row(children: [
      action(Icons.bookmarks_outlined, l.bookmarks, const BookmarksPage()),
      action(Icons.history, l.history, const HistoryPage()),
      action(Icons.folder_outlined, l.files, const DownloadsPage()),
      action(Icons.settings_outlined, l.settings, const SettingsPage()),
    ]);
  }
}

class _PrivateInfo extends StatelessWidget {
  const _PrivateInfo({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: color);
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.privacy_tip_outlined, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.privateTitle,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(l.privateDoes, style: style),
          const SizedBox(height: 8),
          Text(l.privateDoesNot, style: style),
        ]),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(text),
        ),
      );
}
