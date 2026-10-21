import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../browser/browser_tab.dart';
import '../../data/site_permissions_repository.dart';
import '../../l10n/l10n.dart';

/// Connection info + per-site controls (blocking exception, permissions,
/// clear site data).
Future<void> showSiteInfoSheet(
    BuildContext context, WidgetRef ref, BrowserTab tab) async {
  final url = tab.url;
  if (url == null) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _SiteInfo(tab: tab, url: url),
  );
}

class _SiteInfo extends ConsumerStatefulWidget {
  const _SiteInfo({required this.tab, required this.url});
  final BrowserTab tab;
  final Uri url;

  @override
  ConsumerState<_SiteInfo> createState() => _SiteInfoState();
}

class _SiteInfoState extends ConsumerState<_SiteInfo> {
  Map<SitePermission, PermissionDecision> _perms = const {};

  String get host => widget.url.host.replaceFirst(RegExp(r'^www\.'), '');

  @override
  void initState() {
    super.initState();
    _loadPerms();
  }

  Future<void> _loadPerms() async {
    final p = await ref.read(sitePermissionsProvider).forHost(widget.url.host);
    if (mounted) setState(() => _perms = p);
  }

  Future<void> _clearSiteData() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.clearSiteDataTitle(host)),
        content: Text(l.clearSiteDataBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(l.clear)),
        ],
      ),
    );
    if (ok != true) return;
    final webUrl = WebUri.uri(widget.url);
    await CookieManager.instance().deleteCookies(url: webUrl);
    final origin = '${widget.url.scheme}://${widget.url.authority}';
    if (Platform.isAndroid) {
      await WebStorageManager.instance().deleteOrigin(origin: origin);
    } else {
      final records = await WebStorageManager.instance()
          .fetchDataRecords(dataTypes: WebsiteDataType.ALL);
      await WebStorageManager.instance().removeDataFor(
        dataTypes: WebsiteDataType.ALL,
        dataRecords: records
            .where((r) => (r.displayName ?? '').contains(host))
            .toList(),
      );
    }
    await ref.read(sitePermissionsProvider).clearHost(widget.url.host);
    await widget.tab.controller?.reload();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.siteDataCleared)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final blocking = ref.watch(blockingProvider);
    final tab = widget.tab;
    final secure = tab.security == SecurityState.secure;
    final excepted = blocking.exceptions.any(
        (e) => host == e || host.endsWith('.$e'));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.url.host,
              style: Theme.of(context).textTheme.titleLarge,
              textDirection: TextDirection.ltr),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(secure ? Icons.lock_outline : Icons.lock_open,
                color: secure ? null : Theme.of(context).colorScheme.error),
            title: Text(secure ? l.connectionSecure : l.connectionInsecure),
            subtitle: Text(secure ? l.connectionSecureHint : l.connectionInsecureHint),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.shield_outlined),
            title: Text(l.blockOnThisSite),
            subtitle: Text(blocking.enabled
                ? l.blockOnThisSiteHint
                : l.blockingGloballyOff),
            value: blocking.enabled && !excepted,
            onChanged: blocking.enabled
                ? (v) async {
                    await blocking.setSiteException(host, excepted: !v);
                    await tab.controller?.reload();
                  }
                : null,
          ),
          if (_perms.isNotEmpty && !tab.isPrivate) ...[
            const Divider(),
            Text(l.sitePermissions,
                style: Theme.of(context).textTheme.titleSmall),
            for (final e in _perms.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(switch (e.key) {
                  SitePermission.camera => l.camera,
                  SitePermission.microphone => l.microphone,
                  SitePermission.location => l.location,
                }),
                subtitle: Text(e.value == PermissionDecision.allow
                    ? l.allowed
                    : l.denied),
                trailing: TextButton(
                  onPressed: () async {
                    await ref
                        .read(sitePermissionsProvider)
                        .clearHost(widget.url.host);
                    await _loadPerms();
                  },
                  child: Text(l.reset),
                ),
              ),
          ],
          if (!tab.isPrivate) ...[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(l.clearSiteData),
              onTap: _clearSiteData,
            ),
          ],
        ]),
      ),
    );
  }
}
