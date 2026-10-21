import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/history_repository.dart';
import '../../l10n/l10n.dart';
import 'browser_actions.dart';

Future<void> openSearchScreen(
  BuildContext context,
  WidgetRef ref, {
  String initialText = '',
  bool newTab = false,
}) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => SearchScreen(initialText: initialText, newTab: newTab),
  ));
}

/// Address/search entry with local suggestions (history + bookmarks).
/// Suggestions never leave the device: no remote suggest API is called.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialText = '', this.newTab = false});
  final String initialText;
  final bool newTab;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _text;
  List<HistoryEntry> _suggestions = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText)
      ..selection = TextSelection(
          baseOffset: 0, extentOffset: widget.initialText.length);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final private = ref.read(tabsProvider).current?.isPrivate ?? false;
    if (private) return; // private mode does not read history either
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final s = await ref.read(historyRepoProvider).suggest(value);
      if (mounted) setState(() => _suggestions = s);
    });
  }

  Future<void> _submit(String value) async {
    final actions = BrowserActions(ref, context);
    Navigator.of(context).pop();
    await actions.submitInput(value, newTab: widget.newTab);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final engine = ref.watch(settingsProvider).searchEngine;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _text,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: l.searchWith(engine.name),
            suffixIcon: IconButton(
              tooltip: l.clear,
              icon: const Icon(Icons.clear),
              onPressed: () {
                _text.clear();
                _onChanged('');
              },
            ),
          ),
          onChanged: _onChanged,
          onSubmitted: _submit,
        ),
        actions: [
          IconButton(
            tooltip: l.paste,
            icon: const Icon(Icons.content_paste),
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              final t = data?.text?.trim();
              if (t != null && t.isNotEmpty) {
                _text.text = t;
                _onChanged(t);
              }
            },
          ),
        ],
      ),
      body: ListView(children: [
        for (final s in _suggestions)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(s.title.isEmpty ? s.host : s.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(s.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr),
            onTap: () => _submit(s.url),
            trailing: IconButton(
              tooltip: l.editSuggestion,
              icon: const Icon(Icons.north_west),
              onPressed: () {
                _text.text = s.url;
                _text.selection =
                    TextSelection.collapsed(offset: s.url.length);
              },
            ),
          ),
      ]),
    );
  }
}
