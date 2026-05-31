import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../core/errors/user_messages.dart';
import '../../core/openers/attachment_opener.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/theme/feed_layout.dart';
import '../../core/theme/meshpad_colors.dart';
import 'attachment_grid.dart';
import 'feed_screen.dart';

class NoteBubble extends ConsumerStatefulWidget {
  const NoteBubble({
    super.key,
    required this.note,
    this.isTrash = false,
  });

  final Note note;
  final bool isTrash;

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
    final compact = isCompactFeedLayout(context);
    final metaStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: MeshPadColors.textMuted,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final attachmentUriBuilder = notesService == null
        ? null
        : (AttachmentMeta attachment) =>
            notesService.attachmentUri(note.id, attachment.name);

    Future<void> openLink(String href) async {
      try {
        await openMarkdownLink(
          href: href,
          note: note,
          dataDir: dataDir,
          attachmentUriBuilder: attachmentUriBuilder,
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    }

    Future<void> openAttachment(AttachmentMeta attachment) async {
      try {
        await openNoteAttachment(
          note: note,
          attachment: attachment,
          dataDir: dataDir,
          remoteUri: attachmentUriBuilder?.call(attachment),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e))),
        );
      }
    }

    return Card(
      margin: compact ? EdgeInsets.zero : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 12, compact ? 4 : 8, 12),
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
                          data: linkifyBareUrls(
                            note.markdown.isEmpty
                                ? '_Пустая заметка_'
                                : note.markdown,
                          ),
                          onTapLink: (text, href, title) {
                            if (href == null) return;
                            openLink(href);
                          },
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium,
                            h1: Theme.of(context).textTheme.titleMedium,
                            a: const TextStyle(
                              color: MeshPadColors.primary,
                              decoration: TextDecoration.underline,
                            ),
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
              attachmentUriBuilder: attachmentUriBuilder,
              onOpenAttachment: openAttachment,
            ),
            const SizedBox(height: 8),
            Text(
              formatNoteDate(note.updatedAt),
              style: metaStyle,
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
