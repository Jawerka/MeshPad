import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../l10n/app_localizations.dart';
import '../../core/errors/user_messages.dart';
import '../../core/openers/attachment_opener.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/theme/feed_layout.dart';
import '../../core/theme/meshpad_colors.dart';
import 'attachment_grid.dart';
import 'feed_screen.dart';
import 'note_tags_editor.dart';

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
    final isWeb = ref.watch(isWebClientProvider);
    final metaStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: MeshPadColors.textMuted,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final attachmentUriBuilder = notesService == null
        ? null
        : (AttachmentMeta attachment) =>
            notesService.attachmentUri(note.id, attachment.name);
    final attachmentThumbUriBuilder = notesService == null
        ? null
        : (AttachmentMeta attachment) {
            if (!isImageAttachment(attachment)) return null;
            return notesService.attachmentThumbUri(note.id, attachment.name);
          };

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
                      : _buildMarkdownBody(context, note, openLink),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (action) async {
                    switch (action) {
                      case 'edit':
                        setState(() => _editing = true);
                      case 'tags':
                        final next = await showNoteTagsEditorDialog(
                          context,
                          initialTags: note.tags,
                        );
                        if (next == null || !context.mounted) return;
                        await ref
                            .read(notesListProvider.notifier)
                            .setNoteTags(note.id, next);
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
                    final l10n = AppLocalizations.of(context);
                    if (widget.isTrash) {
                      return [
                        PopupMenuItem(
                          value: 'restore',
                          child: Text(l10n.noteMenuRestore),
                        ),
                      ];
                    }
                    return [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(l10n.noteMenuEdit),
                      ),
                      if (!isWeb)
                        PopupMenuItem(
                          value: 'tags',
                          child: Text(l10n.noteMenuTags),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(l10n.noteMenuTrash),
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
              attachmentThumbUriBuilder: attachmentThumbUriBuilder,
              onOpenAttachment: openAttachment,
            ),
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final tag in note.tags)
                    ActionChip(
                      label: Text('#$tag'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: isWeb
                          ? null
                          : () {
                              ref.read(feedTagFilterProvider.notifier).state =
                                  tag;
                              ref.invalidate(notesListProvider);
                            },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  formatNoteDate(note.updatedAt),
                  style: metaStyle,
                ),
                if (widget.isTrash && note.deletedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '· удалится ${formatNoteDate(note.deletedAt!.add(const Duration(days: 7)))}',
                    style: metaStyle,
                  ),
                ],
              ],
            ),
            if (_editing) ...[
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                  _editing = false;
                                  _bodyController.text = note.markdown;
                                }),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.save),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownBody(
    BuildContext context,
    Note note,
    Future<void> Function(String href) openLink,
  ) {
    final markdown = note.markdown.trim();
    if (markdown.isEmpty && note.attachments.isNotEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    return MarkdownBody(
      data: linkifyBareUrls(
        markdown.isEmpty ? l10n.emptyNotePlaceholder : note.markdown,
      ),
      onTapLink: (text, href, title) {
        if (href == null) return;
        openLink(href);
      },
      styleSheet: _markdownStyleSheet(context),
    );
  }

  MarkdownStyleSheet _markdownStyleSheet(BuildContext context) {
    return MarkdownStyleSheet(
      p: Theme.of(context).textTheme.bodyMedium,
      h1: Theme.of(context).textTheme.titleMedium,
      a: TextStyle(
        color: MeshPadColors.primary,
        decoration: TextDecoration.underline,
      ),
      code: TextStyle(
        fontFamily: 'Consolas',
        backgroundColor: MeshPadColors.backgroundElevated,
      ),
    );
  }
}
