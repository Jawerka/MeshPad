import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../core/providers/notes_providers.dart';
import '../../core/theme/meshpad_colors.dart';
import 'attachment_grid.dart';
import 'feed_screen.dart';

class NoteBubble extends ConsumerStatefulWidget {
  const NoteBubble({
    super.key,
    required this.note,
    this.isTrash = false,
    this.syncStatus = NoteSyncStatus.synced,
  });

  final Note note;
  final bool isTrash;
  final NoteSyncStatus syncStatus;

  @override
  ConsumerState<NoteBubble> createState() => _NoteBubbleState();
}

class _NoteBubbleState extends ConsumerState<NoteBubble> {
  var _editing = false;
  late TextEditingController _bodyController;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController(text: widget.note.markdown);
  }

  @override
  void didUpdateWidget(covariant NoteBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.note.updatedAt != widget.note.updatedAt) {
      _bodyController.text = widget.note.markdown;
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(notesListProvider.notifier).updateNote(
            widget.note.id,
            markdown: _bodyController.text,
          );
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final notesService = ref.watch(notesServiceProvider).valueOrNull;
    final dataDir = ref.watch(dataDirProvider).valueOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _editing
                      ? TextField(
                          controller: _bodyController,
                          minLines: 1,
                          maxLines: 10,
                          decoration: const InputDecoration(
                            hintText: 'Markdown',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          textInputAction: TextInputAction.newline,
                        )
                      : MarkdownBody(
                          data: note.markdown.isEmpty
                              ? '_Пустая заметка_'
                              : note.markdown,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium,
                            h1: Theme.of(context).textTheme.titleMedium,
                            code: const TextStyle(
                              fontFamily: 'Consolas',
                              backgroundColor: MeshPadColors.backgroundElevated,
                            ),
                          ),
                        ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (action) async {
                    switch (action) {
                      case 'edit':
                        setState(() => _editing = true);
                      case 'delete':
                        await ref
                            .read(notesListProvider.notifier)
                            .deleteNote(note.id);
                      case 'restore':
                        await ref
                            .read(notesListProvider.notifier)
                            .restoreNote(note.id);
                    }
                  },
                  itemBuilder: (context) {
                    if (widget.isTrash) {
                      return [
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Восстановить'),
                        ),
                      ];
                    }
                    return [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('В корзину'),
                      ),
                    ];
                  },
                ),
              ],
            ),
            AttachmentGrid(
              note: note,
              dataDir: dataDir,
              attachmentUriBuilder: notesService == null
                  ? null
                  : (attachment) =>
                      notesService.attachmentUri(note.id, attachment.name),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(note.author, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 8),
                Text('·', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 8),
                Text(
                  formatNoteDate(note.updatedAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (widget.syncStatus != NoteSyncStatus.synced) ...[
                  const SizedBox(width: 8),
                  Icon(
                    switch (widget.syncStatus) {
                      NoteSyncStatus.pending => Icons.cloud_upload_outlined,
                      NoteSyncStatus.error => Icons.cloud_off_outlined,
                      NoteSyncStatus.synced => Icons.check,
                    },
                    size: 14,
                    color: widget.syncStatus == NoteSyncStatus.error
                        ? MeshPadColors.danger
                        : MeshPadColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    switch (widget.syncStatus) {
                      NoteSyncStatus.pending => 'в очереди',
                      NoteSyncStatus.error => 'ошибка sync',
                      NoteSyncStatus.synced => '',
                    },
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: widget.syncStatus == NoteSyncStatus.error
                              ? MeshPadColors.danger
                              : null,
                        ),
                  ),
                ],
              ],
            ),
            if (_editing) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _editing = false;
                              _bodyController.text = note.markdown;
                            }),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
