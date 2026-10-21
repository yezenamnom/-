import 'package:flutter/material.dart';

import '../../core/search_engines.dart';
import '../../core/url_input.dart';
import '../../data/shortcuts_repository.dart';
import '../../l10n/l10n.dart';

/// Add/edit a shortcut. Only http(s) sites are accepted.
Future<ShortcutItem?> showShortcutEditor(
  BuildContext context, {
  ShortcutItem? existing,
}) {
  return showDialog<ShortcutItem>(
    context: context,
    builder: (_) => _ShortcutEditor(existing: existing),
  );
}

class _ShortcutEditor extends StatefulWidget {
  const _ShortcutEditor({this.existing});
  final ShortcutItem? existing;

  @override
  State<_ShortcutEditor> createState() => _ShortcutEditorState();
}

class _ShortcutEditorState extends State<_ShortcutEditor> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _url = TextEditingController(text: widget.existing?.url);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Uri? _parse(String text) {
    final r = resolveInput(text, searchEngineById(null));
    return r is NavigateTo ? r.uri : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.existing == null ? l.addShortcut : l.editShortcut),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _title,
            decoration: InputDecoration(labelText: l.name),
            maxLength: 40,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l.requiredField : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _url,
            decoration: InputDecoration(labelText: l.address),
            keyboardType: TextInputType.url,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            validator: (v) => _parse(v ?? '') == null ? l.invalidAddress : null,
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final e = widget.existing;
            Navigator.pop(
              context,
              ShortcutItem(
                id: e?.id ?? ShortcutsRepository.newId(),
                title: _title.text.trim(),
                url: _parse(_url.text)!.toString(),
                iconKey: e?.iconKey,
                color: e?.color,
                remoteId: e?.remoteId,
              ),
            );
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
