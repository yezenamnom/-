import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../browser/browser_tab.dart';
import '../../core/url_safety.dart';
import '../../l10n/l10n.dart';
import '../browser/browser_actions.dart';
import '../theme.dart';

/// Tab switcher with its own background, a normal/private toggle, search,
/// close-all with confirmation. Private tabs never show page previews.
/// Pops `true` when the user picked a tab (natural transition).
class TabsScreen extends ConsumerStatefulWidget {
  const TabsScreen({super.key});

  @override
  ConsumerState<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends ConsumerState<TabsScreen> {
  late bool _private;
  String _query = '';
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _private = ref.read(tabsProvider).current?.isPrivate ?? false;
  }

  Future<void> _closeAll() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_private ? l.closeAllPrivateTitle : l.closeAllTitle),
        content: Text(_private ? l.closeAllPrivateBody : l.closeAllBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l.closeAll)),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(tabsProvider).closeAll(private: _private);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tabsCtl = ref.watch(tabsProvider);
    final list = tabsCtl.search(_query, private: _private);
    final scheme = Theme.of(context).colorScheme;
    final bg = _private
        ? AppTheme.privateBackground(Theme.of(context).brightness)
        : AppTheme.tabsBackground(scheme);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 900 ? 4 : (width > 600 ? 3 : 2);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: _private ? Colors.white : null,
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(hintText: l.searchTabs),
                onChanged: (v) => setState(() => _query = v),
              )
            : SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                      value: false,
                      label: Text('${l.tabs} (${tabsCtl.normalTabs.length})')),
                  ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                      label: Text('${tabsCtl.privateTabs.length}',
                          semanticsLabel: l.privateTabs)),
                ],
                selected: {_private},
                onSelectionChanged: (s) => setState(() => _private = s.first),
              ),
        actions: [
          IconButton(
            tooltip: _searching ? l.close : l.searchTabs,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'closeAll') _closeAll();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'closeAll',
                enabled: list.isNotEmpty,
                child: Text(l.closeAll),
              ),
            ],
          ),
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Text(_private ? l.noPrivateTabs : l.noTabs,
                  style: TextStyle(color: _private ? Colors.white70 : null)),
            )
          : ReorderableGridish(
              columns: columns,
              tabs: list,
              currentId: tabsCtl.current?.id,
              enableReorder: _query.isEmpty,
              onReorder: (a, b) =>
                  tabsCtl.reorder(a, b, private: _private),
              onSelect: (t) {
                tabsCtl.select(t.id);
                Navigator.pop(context, true);
              },
              onClose: (t) => tabsCtl.close(t.id),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final actions = BrowserActions(ref, context);
          await actions.newTab(private: _private);
          if (context.mounted) Navigator.pop(context, false);
        },
        icon: const Icon(Icons.add),
        label: Text(_private ? l.newPrivateTab : l.newTab),
      ),
    );
  }
}

/// Grid of tab cards. Reordering uses long-press + arrows in the card menu
/// to stay accessible (no drag-only interaction).
class ReorderableGridish extends StatelessWidget {
  const ReorderableGridish({
    super.key,
    required this.columns,
    required this.tabs,
    required this.currentId,
    required this.enableReorder,
    required this.onReorder,
    required this.onSelect,
    required this.onClose,
  });

  final int columns;
  final List<BrowserTab> tabs;
  final String? currentId;
  final bool enableReorder;
  final void Function(int from, int to) onReorder;
  final ValueChanged<BrowserTab> onSelect;
  final ValueChanged<BrowserTab> onClose;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: tabs.length,
      itemBuilder: (context, i) {
        final t = tabs[i];
        return _TabCard(
          tab: t,
          selected: t.id == currentId,
          onTap: () => onSelect(t),
          onClose: () => onClose(t),
          onMoveEarlier:
              enableReorder && i > 0 ? () => onReorder(i, i - 1) : null,
          onMoveLater: enableReorder && i < tabs.length - 1
              ? () => onReorder(i, i + 1)
              : null,
        );
      },
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
    this.onMoveEarlier,
    this.onMoveLater,
  });

  final BrowserTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback? onMoveEarlier;
  final VoidCallback? onMoveLater;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final url = tab.url;
    final title = tab.title.isNotEmpty
        ? tab.title
        : (url == null ? l.newTab : displayHost(url));
    final thumb = tab.isPrivate ? null : tab.thumbnail;

    return Semantics(
      selected: selected,
      label: title,
      child: Material(
        color: scheme.surface,
        elevation: selected ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: selected
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: (onMoveEarlier == null && onMoveLater == null)
              ? null
              : () => showModalBottomSheet<void>(
                    context: context,
                    builder: (c) => SafeArea(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (onMoveEarlier != null)
                          ListTile(
                            leading: const Icon(Icons.arrow_back),
                            title: Text(l.moveEarlier),
                            onTap: () {
                              Navigator.pop(c);
                              onMoveEarlier!();
                            },
                          ),
                        if (onMoveLater != null)
                          ListTile(
                            leading: const Icon(Icons.arrow_forward),
                            title: Text(l.moveLater),
                            onTap: () {
                              Navigator.pop(c);
                              onMoveLater!();
                            },
                          ),
                      ]),
                    ),
                  ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 0, 4),
              child: Row(children: [
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                IconButton(
                  tooltip: l.closeTab,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ]),
            ),
            Expanded(
              child: thumb != null
                  ? Image.memory(thumb,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      gaplessPlayback: true)
                  : ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          tab.isPrivate
                              ? Icons.privacy_tip_outlined
                              : Icons.public,
                          size: 40,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
            if (url != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(displayHost(url),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ]),
        ),
      ),
    );
  }
}
