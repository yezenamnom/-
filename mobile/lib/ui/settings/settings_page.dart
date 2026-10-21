import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_providers.dart';
import '../../blocking/blocking_service.dart';
import '../../core/search_engines.dart';
import '../../data/history_repository.dart';
import '../../data/settings_controller.dart';
import '../../l10n/l10n.dart';
import '../browser/browser_menu.dart';
import '../report/report_page.dart';
import 'subscription_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final blocking = ref.watch(blockingProvider);
    final ads = ref.watch(adsProvider);
    final sub = ref.watch(subscriptionProvider);
    final content = ref.watch(configProvider).config.content;
    final lang = Localizations.localeOf(context).languageCode;

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(t,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(children: [
        header(l.general),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l.language),
          subtitle: Text(_languageName(l, s.locale?.languageCode)),
          onTap: () => _pickLanguage(context, s),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: Text(l.theme),
          subtitle: Text(switch (s.themeMode) {
            ThemeMode.light => l.themeLight,
            ThemeMode.dark => l.themeDark,
            ThemeMode.system => l.followSystem,
          }),
          onTap: () => _pickTheme(context, s),
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: Text(l.searchEngine),
          subtitle: Text(s.searchEngine.name),
          onTap: () => _pickEngine(context, s),
        ),
        ListTile(
          leading: const Icon(Icons.format_size),
          title: Text(l.textSize),
          subtitle: Slider(
            value: (s.textScale * 100).clamp(50, 200),
            min: 50,
            max: 200,
            divisions: 15,
            label: '${(s.textScale * 100).round()}%',
            onChanged: (v) => s.setTextZoom(v.round()),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.restore),
          title: Text(l.restoreTabs),
          value: s.restoreTabs,
          onChanged: s.setRestoreTabs,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.desktop_windows_outlined),
          title: Text(l.desktopSiteDefault),
          value: s.desktopModeDefault,
          onChanged: s.setDesktopModeDefault,
        ),

        header(l.contentBlocking),
        SwitchListTile(
          secondary: const Icon(Icons.shield_outlined),
          title: Text(l.blockAdsTrackers),
          subtitle: Text(l.blockAdsTrackersHint),
          value: blocking.enabled,
          onChanged: blocking.setEnabled,
        ),
        ListTile(
          leading: const Icon(Icons.rule),
          title: Text(l.blockingExceptions),
          subtitle: Text(blocking.exceptions.isEmpty
              ? l.none
              : blocking.exceptions.join(', '),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => _editExceptions(context, blocking),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l.blocklistVersion(blocking.list.version)),
          subtitle: Text(
              '${blocking.list.name} · ${l.rulesCount(blocking.list.rules.length)}'),
          trailing: blocking.source == BlocklistSource.downloaded
              ? TextButton(
                  onPressed: blocking.revertToPrevious,
                  child: Text(l.revertBlocklist))
              : null,
        ),

        header(l.privacy),
        ListTile(
          leading: const Icon(Icons.delete_forever_outlined),
          title: Text(l.clearBrowsingData),
          onTap: () => _clearBrowsingData(context, ref),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.cookie_outlined),
          title: Text(l.thirdPartyCookies),
          subtitle: Text(l.thirdPartyCookiesHint),
          value: s.thirdPartyCookies,
          onChanged: s.setThirdPartyCookies,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.open_in_browser),
          title: Text(l.blockPopups),
          value: s.blockPopups,
          onChanged: s.setBlockPopups,
        ),
        SwitchListTile(
          secondary: const Icon(Icons.javascript),
          title: Text(l.javascript),
          value: s.javascriptEnabled,
          onChanged: s.setJavascriptEnabled,
        ),

        header(l.media),
        SwitchListTile(
          secondary: const Icon(Icons.headphones_outlined),
          title: Text(l.backgroundAudio),
          subtitle: Text(l.backgroundAudioHint),
          value: s.backgroundAudio,
          onChanged: s.setBackgroundAudio,
        ),
        if (Platform.isAndroid)
          SwitchListTile(
            secondary: const Icon(Icons.picture_in_picture_alt_outlined),
            title: Text(l.autoPip),
            subtitle: Text(l.autoPipHint),
            value: s.autoPip,
            onChanged: s.setAutoPip,
          ),

        header(l.adsAndSubscription),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l.appAdsExplained),
          subtitle: Text(l.appAdsExplainedBody),
        ),
        if (ads.consent.privacyOptionsRequired)
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.adPrivacyOptions),
            onTap: ads.showPrivacyOptions,
          ),
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: Text(l.removeAds),
          subtitle: Text(sub.adFree ? l.adFreeActive : l.removeAdsHint),
          onTap: () => pushPage(context, const SubscriptionPage()),
        ),

        header(l.about),
        if (content.privacyUrl != null)
          _LinkTile(Icons.policy_outlined, l.privacyPolicy, content.privacyUrl!),
        if (content.termsUrl != null)
          _LinkTile(Icons.gavel_outlined, l.terms, content.termsUrl!),
        if (content.supportUrl != null)
          _LinkTile(Icons.support_agent, l.support, content.supportUrl!),
        if (content.helpText.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(l.help),
            subtitle: Text(content.helpText[lang] ?? content.helpText['en']!),
          ),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: Text(l.reportProblem),
          onTap: () => pushPage(context, const ReportPage()),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(l.openSourceLicenses),
          onTap: () => showLicensePage(
            context: context,
            applicationName: l.appName,
            applicationVersion: ref.read(configProvider).appVersion,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.verified_outlined),
          title: Text(l.version),
          subtitle: Text(ref.read(configProvider).appVersion),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  String _languageName(AppLocalizations l, String? code) => switch (code) {
        'ar' => 'العربية',
        'en' => 'English',
        'de' => 'Deutsch',
        _ => l.followSystem,
      };

  Future<void> _pickLanguage(BuildContext context, SettingsController s) async {
    final l = context.l10n;
    final code = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: Text(l.language), children: [
        for (final code in ['system', ...SettingsController.supportedLanguages])
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, code),
            child: Text(_languageName(l, code == 'system' ? null : code)),
          ),
      ]),
    );
    if (code == null) return;
    await s.setLocale(code == 'system' ? null : Locale(code));
  }

  Future<void> _pickTheme(BuildContext context, SettingsController s) async {
    final l = context.l10n;
    final m = await showDialog<ThemeMode>(
      context: context,
      builder: (c) => SimpleDialog(title: Text(l.theme), children: [
        for (final (m, t) in [
          (ThemeMode.system, l.followSystem),
          (ThemeMode.light, l.themeLight),
          (ThemeMode.dark, l.themeDark),
        ])
          SimpleDialogOption(
              onPressed: () => Navigator.pop(c, m), child: Text(t)),
      ]),
    );
    if (m != null) await s.setThemeMode(m);
  }

  Future<void> _pickEngine(BuildContext context, SettingsController s) async {
    final l = context.l10n;
    final id = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: Text(l.searchEngine), children: [
        for (final e in kSearchEngines)
          SimpleDialogOption(
              onPressed: () => Navigator.pop(c, e.id), child: Text(e.name)),
      ]),
    );
    if (id != null) await s.setSearchEngine(id);
  }

  Future<void> _editExceptions(
      BuildContext context, BlockingService blocking) async {
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setState) {
        final list = blocking.exceptions.toList()..sort();
        return AlertDialog(
          title: Text(c.l10n.blockingExceptions),
          content: SizedBox(
            width: double.maxFinite,
            child: list.isEmpty
                ? Text(c.l10n.blockingExceptionsEmpty)
                : ListView(shrinkWrap: true, children: [
                    for (final h in list)
                      ListTile(
                        title: Text(h, textDirection: TextDirection.ltr),
                        trailing: IconButton(
                          tooltip: c.l10n.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await blocking.setSiteException(h, excepted: false);
                            setState(() {});
                          },
                        ),
                      ),
                  ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: Text(c.l10n.close)),
          ],
        );
      }),
    );
  }

  Future<void> _clearBrowsingData(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    var history = true, cookies = true, cache = true, permissions = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text(l.clearBrowsingData),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            CheckboxListTile(
                value: history,
                title: Text(l.history),
                onChanged: (v) => setState(() => history = v!)),
            CheckboxListTile(
                value: cookies,
                title: Text(l.cookiesAndSiteData),
                subtitle: Text(l.cookiesSignOutHint),
                onChanged: (v) => setState(() => cookies = v!)),
            CheckboxListTile(
                value: cache,
                title: Text(l.cache),
                onChanged: (v) => setState(() => cache = v!)),
            CheckboxListTile(
                value: permissions,
                title: Text(l.sitePermissions),
                onChanged: (v) => setState(() => permissions = v!)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
            FilledButton(
                onPressed: () => Navigator.pop(c, true), child: Text(l.clear)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (history) {
      await ref.read(historyRepoProvider).deleteRange(HistoryRange.all);
    }
    if (cookies) {
      await CookieManager.instance().deleteAllCookies();
      if (Platform.isAndroid) {
        await WebStorageManager.instance().deleteAllData();
      } else {
        await WebStorageManager.instance().removeDataModifiedSince(
          dataTypes: WebsiteDataType.ALL,
          date: DateTime.fromMillisecondsSinceEpoch(0),
        );
      }
    }
    if (cache) await InAppWebViewController.clearAllCache();
    if (permissions) await ref.read(sitePermissionsProvider).clearAll();
    ref.read(dataRevisionProvider.notifier).state++;
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.browsingDataCleared)));
    }
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile(this.icon, this.title, this.url);
  final IconData icon;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication),
      );
}
