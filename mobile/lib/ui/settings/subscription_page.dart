import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_providers.dart';
import '../../billing/subscription_service.dart';
import '../../l10n/l10n.dart';

/// "Remove ads" subscription. Removes this app's own ads only. Prices and
/// periods are shown exactly as the store returns them.
class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final sub = ref.watch(subscriptionProvider);
    final ent = sub.entitlement;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final content = ref.watch(configProvider).config.content;

    return Scaffold(
      appBar: AppBar(title: Text(l.removeAds)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(l.subscriptionScope, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        if (sub.adFree && ent != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(l.adFreeActive),
              subtitle: Text(l.validUntil(
                  DateFormat.yMMMd(locale).format(ent.expiresAt.toLocal()))),
            ),
          ),
        switch (sub.availability) {
          SubscriptionAvailability.notConfigured =>
            _Info(text: l.subscriptionNotConfigured),
          SubscriptionAvailability.storeUnavailable =>
            _Info(text: l.storeUnavailable),
          SubscriptionAvailability.productsMissing =>
            _Info(text: l.productsMissing),
          SubscriptionAvailability.ready => Column(children: [
              for (final p in sub.products)
                Card(
                  child: ListTile(
                    title: Text(p.title),
                    subtitle: Text(p.description),
                    trailing: FilledButton(
                      onPressed: sub.busy ? null : () => sub.buy(p),
                      child: Text(p.price),
                    ),
                  ),
                ),
            ]),
        },
        if (sub.lastError != null) ...[
          const SizedBox(height: 8),
          Text(l.purchaseError(sub.lastError!),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        if (sub.isConfigured)
          OutlinedButton(
            onPressed: sub.busy ? null : sub.restore,
            child: Text(l.restorePurchases),
          ),
        const SizedBox(height: 16),
        Text(l.subscriptionManageHint,
            style: Theme.of(context).textTheme.bodySmall),
        // Store rules: terms and privacy must be reachable from the
        // purchase screen itself.
        Wrap(spacing: 8, children: [
          for (final (label, url) in [
            (l.terms, content.termsUrl),
            (l.privacyPolicy, content.privacyUrl),
          ])
            if (url != null)
              TextButton(
                onPressed: () => launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication),
                child: Text(label),
              ),
        ]),
      ]),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(leading: const Icon(Icons.info_outline), title: Text(text)),
      );
}
