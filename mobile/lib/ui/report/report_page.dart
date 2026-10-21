import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../l10n/l10n.dart';
import '../../reports/report_service.dart';

/// Voluntary problem report. Shows exactly what will be sent before
/// sending; no URL path, cookies, history or page content is included.
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key, this.siteHost});
  final String? siteHost;

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  ReportCategory _category = ReportCategory.siteBroken;
  final _message = TextEditingController();
  late bool _includeHost = widget.siteHost != null;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  UserReport _build() => UserReport(
        category: _category,
        message: _message.text,
        appVersion: ref.read(configProvider).appVersion,
        platform: Platform.isAndroid ? 'android' : 'ios',
        locale: Localizations.localeOf(context).languageCode,
        siteHost: _includeHost ? widget.siteHost : null,
      );

  Future<void> _send() async {
    final l = context.l10n;
    final report = _build();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.reportPreviewTitle),
        content: SingleChildScrollView(
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(report.toJson()),
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(l.send)),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sending = true);
    final sent = await ref.read(reportServiceProvider).send(report);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sent ? l.reportSent : l.reportFailed)));
    if (sent) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final available = ref.read(reportServiceProvider).available;
    return Scaffold(
      appBar: AppBar(title: Text(l.reportProblem)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!available) Card(child: ListTile(title: Text(l.reportUnavailable))),
        DropdownButtonFormField<ReportCategory>(
          initialValue: _category,
          decoration: InputDecoration(labelText: l.category),
          items: [
            for (final (c, t) in [
              (ReportCategory.siteBroken, l.catSiteBroken),
              (ReportCategory.blockingIssue, l.catBlocking),
              (ReportCategory.videoIssue, l.catVideo),
              (ReportCategory.adsIssue, l.catAds),
              (ReportCategory.other, l.catOther),
            ])
              DropdownMenuItem(value: c, child: Text(t)),
          ],
          onChanged: (v) => setState(() => _category = v!),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _message,
          maxLines: 6,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: l.describeProblem,
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (widget.siteHost != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeHost,
            title: Text(l.includeSiteHost(widget.siteHost!)),
            subtitle: Text(l.includeSiteHostHint),
            onChanged: (v) => setState(() => _includeHost = v!),
          ),
        const SizedBox(height: 8),
        Text(l.reportPrivacyNote, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: (!available || _sending) ? null : _send,
          child: Text(l.reviewAndSend),
        ),
      ]),
    );
  }
}
