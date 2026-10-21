import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../data/bookmarks_repository.dart';
import '../../l10n/l10n.dart';
import '../browser/browser_actions.dart';

class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key, this.folder});
  final BookmarkFolder? folder;

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  String _query = '';

  BookmarksRepository get _repo => ref.read(bookmarksRepoProvider);
  void _bump() => ref.read(dataRevisionProvider.notifier).state++;

  Future<String?> _askName(String title, {String initial = ''}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, maxLength: 80),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: Text(d.l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text.trim()),
              child: Text(d.l10n.save)),
        ],
      ),
    );
  }

  Future<void> _bookmarkMenu(Bookmark b) async {
    final l = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(l.openInNewTab),
              onTap: () => Navigator.pop(c, 'newtab')),
          ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.rename),
              onTap: () => Navigator.pop(c, 'rename')),
          ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(l.moveToFolder),
              onTap: () => Navigator.pop(c, 'move')),
          ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l.delete),
              onTap: () => Navigator.pop(c, 'delete')),
        ]),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'newtab':
        BrowserActions(ref, context).open(Uri.parse(b.url), newTab: true);
        Navigator.of(context).popUntil((r) => r.isFirst);
      case 'rename':
        final name = await _askName(l.rename, initial: b.title);
        if (name != null && name.isNotEmpty) {
          await _repo.update(b.id, title: name);
        }
      case 'move':
        final folders = await _repo.allFolders();
        if (!mounted) return;
        final target = await showDialog<int>(
          context: context,
          builder: (c) => SimpleDialog(
            title: Text(l.moveToFolder),
            children: [
              SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, -1),
                  child: Text(l.bookmarksRoot)),
              for (final f in folders)
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, f.id),
                    child: Text(f.name)),
            ],
          ),
        );
        if (target == -1) {
          await _repo.update(b.id, moveToRoot: true);
        } else if (target != null) {
          await _repo.update(b.id, folderId: target);
        }
      case 'delete':
        await _repo.remove(b.id);
    }
    _bump();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    ref.watch(dataRevisionProvider);
    final folderId = widget.folder?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder?.name ?? l.bookmarks),
        actions: [
          IconButton(
            tooltip: l.newFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () async {
              final name = await _askName(l.newFolder);
              if (name != null && name.isNotEmpty) {
                await _repo.addFolder(name, parentId: folderId);
                _bump();
              }
            },
          ),
          if (widget.folder != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final name =
                      await _askName(l.rename, initial: widget.folder!.name);
                  if (name != null && name.isNotEmpty) {
                    await _repo.renameFolder(folderId!, name);
                  }
                } else if (v == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(l.deleteFolderTitle),
                      content: Text(l.deleteFolderBody),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text(l.cancel)),
                        FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text(l.delete)),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await _repo.removeFolder(folderId!);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
                _bump();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(l.rename)),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
        ],
      ),
      body: Column(children: [
        if (widget.folder == null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l.searchBookmarks),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        Expanded(
          child: FutureBuilder(
            future: Future.wait([
              _query.isEmpty
                  ? _repo.folders(parentId: folderId)
                  : Future.value(<BookmarkFolder>[]),
              _query.isEmpty
                  ? _repo.list(folderId: folderId)
                  : _repo.search(_query),
            ]),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final folders = snap.data![0] as List<BookmarkFolder>;
              final items = snap.data![1] as List<Bookmark>;
              if (folders.isEmpty && items.isEmpty) {
                return Center(child: Text(l.noBookmarks));
              }
              return ListView(children: [
                for (final f in folders)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(f.name),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => BookmarksPage(folder: f)),
                    ),
                  ),
                for (final b in items)
                  ListTile(
                    leading: const Icon(Icons.bookmark_border),
                    title: Text(b.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(b.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr),
                    onTap: () {
                      BrowserActions(ref, context).open(Uri.parse(b.url));
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    trailing: IconButton(
                      tooltip: l.more,
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _bookmarkMenu(b),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
