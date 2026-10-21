import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../browser/browser_tab.dart';
import '../../core/url_safety.dart';
import '../../l10n/l10n.dart';
import 'browser_actions.dart';
import 'search_screen.dart';
import 'site_info_sheet.dart';

/// Shows the site's host prominently (punycode kept visible) with the
/// connection state. Tapping opens the search/edit screen.
class AddressBar extends ConsumerWidget {
  const AddressBar({super.key, required this.tab});
  final BrowserTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final url = tab.url;
    final host = url == null ? '' : displayHost(url);

    final (IconData icon, Color color, String label) = switch (tab.security) {
      SecurityState.secure => (Icons.lock_outline, scheme.onSurfaceVariant, l.connectionSecure),
      SecurityState.insecure => (Icons.lock_open, scheme.error, l.connectionInsecure),
      SecurityState.certificateError => (Icons.gpp_bad_outlined, scheme.error, l.certificateErrorTitle),
      SecurityState.none => (Icons.public, scheme.onSurfaceVariant, ''),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Material(
        color: tab.isPrivate
            ? scheme.inverseSurface.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
        child: Row(children: [
          IconButton(
            tooltip: label.isEmpty ? l.siteInfo : label,
            icon: Icon(icon, color: color, size: 20),
            onPressed: url == null
                ? null
                : () => showSiteInfoSheet(context, ref, tab),
          ),
          if (tab.isPrivate)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Icon(Icons.privacy_tip_outlined,
                  size: 18, color: scheme.primary, semanticLabel: l.privateTab),
            ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => openSearchScreen(context, ref,
                  initialText: url?.toString() ?? ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  label: l.addressBar,
                  value: url?.toString(),
                  child: Text(
                    host.isEmpty ? l.searchOrType : host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Hosts are always LTR, also in Arabic UI.
                    textDirection: TextDirection.ltr,
                    textAlign: Directionality.of(context) == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.left,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: tab.loading ? l.stop : l.reload,
            icon: Icon(tab.loading ? Icons.close : Icons.refresh),
            onPressed: () {
              final c = tab.controller;
              if (tab.loading) {
                c?.stopLoading();
              } else if (tab.errorDescription != null && url != null) {
                BrowserActions(ref, context).loadInTab(tab, url);
              } else {
                c?.reload();
              }
            },
          ),
        ]),
      ),
    );
  }
}
