import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_providers.dart';
import '../../data/history_repository.dart';
import '../../l10n/l10n.dart';
import '../browser/browser_actions.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _query = '';

  void _bump() => ref.read(dataRevisionProvider.notifier).state++;

  Future<void> _clear() async {
    final l = context.l10n;
    final range = await showDialog<HistoryRange>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(l.clearHistory),
        children: [
          for (final (r, label) in [
            (HistoryRange.lastHour, l.rangeLastHour),
            (HistoryRange.today, l.rangeToday),
            (HistoryRange.last7Days, l.rangeLast7Days),
            (HistoryRange.last4Weeks, l.rangeLast4Weeks),
            (HistoryRange.all, l.rangeAll),
          ])
            SimpleDialogOption(
                onPressed: () => Navigator.pop(c, r), child: Text(label)),
        ],
      ),
    );
    if (range == null) return;
    final n = await ref.read(historyRepoProvider).deleteRange(range);
    _bump();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.historyDeleted(n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.watch(dataRevisionProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dayFmt = DateFormat.yMMMMEEEEd(locale);
    final timeFmt = DateFormat.Hm(locale);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.history),
        actions: [
          IconButton(
              tooltip: l.clearHistory,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clear),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.searchHistory),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<HistoryEntry>>(
            future: ref.read(historyRepoProvider).list(query: _query, limit: 500),
            builder: (context, snap) {
              final items = snap.data;
              if (items == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) return Center(child: Text(l.noHistory));
              final children = <Widget>[];
              String? lastDay;
              for (final e in items) {
                final day = dayFmt.format(e.visitedAt);
                if (day != lastDay) {
                  lastDay = day;
                  children.add(Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(day,
                        style: Theme.of(context).textTheme.titleSmall),
                  ));
                }
                children.add(ListTile(
                  title: Text(e.title.isEmpty ? e.host : e.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${timeFmt.format(e.visitedAt)} · ${e.host}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    BrowserActions(ref, context).open(Uri.parse(e.url));
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  trailing: IconButton(
                    tooltip: l.delete,
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await ref.read(historyRepoProvider).deleteEntry(e.id);
                      _bump();
                    },
                  ),
                ));
              }
              return ListView(children: children);
            },
          ),
        ),
      ]),
    );
  }
}
