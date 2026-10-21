import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../ads/banner_slot.dart';
import '../../app_providers.dart';
import '../../config/remote_config.dart';
import '../../downloads/downloads_service.dart';
import '../../l10n/l10n.dart';

/// Files downloaded in the browser. Files are never opened or executed by
/// the app; "Share/Open with" hands them to the OS chooser on request.
class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  String _size(int? bytes) {
    if (bytes == null) return '?';
    const units = ['B', 'KB', 'MB', 'GB'];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final service = ref.watch(downloadsProvider);
    final items = service.items;
    return Scaffold(
      appBar: AppBar(title: Text(l.files)),
      body: Column(children: [
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.noDownloads, textAlign: TextAlign.center),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = items[i];
                    final status = switch (d.status) {
                      DownloadStatus.running => d.totalBytes == null
                          ? l.downloadingBytes(_size(d.receivedBytes))
                          : '${_size(d.receivedBytes)} / ${_size(d.totalBytes)}',
                      DownloadStatus.completed => _size(d.receivedBytes),
                      DownloadStatus.failed => l.downloadFailed(d.error ?? ''),
                      DownloadStatus.canceled => l.downloadCanceled,
                    };
                    return ListTile(
                      leading: Icon(switch (d.status) {
                        DownloadStatus.completed =>
                          Icons.insert_drive_file_outlined,
                        DownloadStatus.running => Icons.downloading,
                        _ => Icons.error_outline,
                      }),
                      title: Text(d.fileName,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(status),
                            if (d.status == DownloadStatus.running)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child:
                                    LinearProgressIndicator(value: d.progress),
                              ),
                          ]),
                      trailing: _actions(context, ref, d),
                    );
                  },
                ),
        ),
        const SafeArea(
          top: false,
          child: BannerSlot(placement: AdPlacementId.downloadsBanner),
        ),
      ]),
    );
  }

  Widget _actions(BuildContext context, WidgetRef ref, DownloadItem d) {
    final l = context.l10n;
    final s = ref.read(downloadsProvider);
    return switch (d.status) {
      DownloadStatus.running => IconButton(
          tooltip: l.cancel,
          icon: const Icon(Icons.close),
          onPressed: () => s.cancel(d.id)),
      _ => PopupMenuButton<String>(
          tooltip: l.more,
          onSelected: (v) async {
            switch (v) {
              case 'share':
                await SharePlus.instance
                    .share(ShareParams(files: [XFile(d.path, mimeType: d.mime)]));
              case 'retry':
                await s.retry(d.id);
              case 'delete':
                await s.delete(d.id);
            }
          },
          itemBuilder: (_) => [
            if (d.status == DownloadStatus.completed)
              PopupMenuItem(value: 'share', child: Text(l.shareOrOpen)),
            if (d.status != DownloadStatus.completed)
              PopupMenuItem(value: 'retry', child: Text(l.retry)),
            PopupMenuItem(value: 'delete', child: Text(l.delete)),
          ],
        ),
    };
  }
}
