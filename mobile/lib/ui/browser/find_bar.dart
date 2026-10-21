import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../l10n/l10n.dart';

class FindBar extends StatelessWidget {
  const FindBar({
    super.key,
    required this.controller,
    required this.status,
    required this.onClose,
  });

  final FindInteractionController controller;
  final ValueNotifier<String> status;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l.findInPage,
                isDense: true,
              ),
              onChanged: (v) => v.isEmpty
                  ? controller.clearMatches()
                  : controller.findAll(find: v),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: status,
            builder: (_, v, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(v),
            ),
          ),
          IconButton(
            tooltip: l.previous,
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: () => controller.findNext(forward: false),
          ),
          IconButton(
            tooltip: l.next,
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => controller.findNext(),
          ),
          IconButton(
            tooltip: l.close,
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ]),
      ),
    );
  }
}
