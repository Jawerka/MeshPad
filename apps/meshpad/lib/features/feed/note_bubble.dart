import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../l10n/app_localizations.dart';
import '../../core/errors/user_messages.dart';
import '../../core/openers/attachment_opener.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/ui/meshpad_status_hint.dart';
import '../../core/ui/status_hint_provider.dart';
import '../../core/theme/feed_layout.dart';
import '../../core/theme/meshpad_colors.dart';
import 'attachment_grid.dart';
import 'feed_screen.dart';
import 'note_conflict_sheet.dart';
import 'note_context_menu.dart';

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

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  List<PopupMenuEntry<String>> _menuItems(
      BuildContext context, bool hasConflicts) {
    return buildNoteContextMenuItems(
      context: context,
      isTrash: widget.isTrash,
      hasConflicts: hasConflicts,
      isWeb: ref.watch(isWebClientProvider),
    );
  }

  Future<void> _onMenuAction(String action) {
    return handleNoteAction(
      action: action,
      context: context,
      ref: ref,
      note: widget.note,
      onEdit: () => setState(() => _editing = true),
      copyAllText: _copyAllText,
    );
  }

  Future<void> _openContextMenuAt(Offset globalPosition) {
    return showNoteContextMenu(
      context: context,
      globalPosition: globalPosition,
      items: _menuItems(context, _hasConflicts),
      onSelected: _onMenuAction,
    );
  }

  bool get _hasConflicts {
    final note = widget.note;
    return ref.watch(noteConflictCopiesProvider(note.id)).maybeWhen(
          data: (c) => c.isNotEmpty,
          orElse: () => false,
        );
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final notesService = ref.watch(notesServiceProvider).valueOrNull;
    final dataDir = ref.watch(dataDirProvider).valueOrNull;
    final compact = isCompactFeedLayout(context);
    final isWeb = ref.watch(isWebClientProvider);
    final hasConflicts = _hasConflicts;
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
        showMeshPadHint(
          context,
          userFacingError(e),
          severity: StatusHintSeverity.error,
        );
      }
    }

    Future<void> openAttachment(AttachmentMeta attachment) async {
      final l10n = AppLocalizations.of(context);
      final savesOnTap = !kIsWeb &&
          !isImageAttachment(attachment) &&
          !isVideoAttachment(attachment) &&
          !isAudioAttachment(attachment);
      try {
        await openNoteAttachment(
          note: note,
          attachment: attachment,
          dataDir: dataDir,
          remoteUri: attachmentUriBuilder?.call(attachment),
        );
        if (!context.mounted || !savesOnTap) return;
        showMeshPadHint(
          context,
          l10n.fileSaved,
          severity: StatusHintSeverity.success,
        );
      } catch (e) {
        if (!context.mounted) return;
        showMeshPadHint(
          context,
          savesOnTap ? l10n.fileSaveFailed : userFacingError(e),
          severity: StatusHintSeverity.error,
        );
      }
    }

    final cardContent = Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 12, compact ? 4 : 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GestureDetector(
                  onLongPress: () {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    unawaited(_openContextMenuAt(
                      box.localToGlobal(box.size.center(Offset.zero)),
                    ));
                  },
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
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (action) => _onMenuAction(action),
                itemBuilder: (context) => _menuItems(context, hasConflicts),
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
          if (hasConflicts) ...[
            const SizedBox(height: 8),
            ActionChip(
              avatar: const Icon(Icons.warning_amber, size: 18),
              label: Text(AppLocalizations.of(context).noteConflictBadge),
              visualDensity: VisualDensity.compact,
              onPressed: () => showNoteConflictSheet(context, ref, note),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
    );

    Widget card = Card(
      margin: compact ? EdgeInsets.zero : null,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: MeshPadColors.border.withValues(alpha: 0.6)),
      ),
      child: cardContent,
    );

    card = GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final center = box.localToGlobal(box.size.center(Offset.zero));
        unawaited(_openContextMenuAt(center));
      },
      onSecondaryTapUp: _isDesktop
          ? (details) => unawaited(_openContextMenuAt(details.globalPosition))
          : null,
      child: card,
    );

    return card;
  }

  String _copyAllText(Note note) => note.markdown.trim();

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
    return SelectionArea(
      contextMenuBuilder: (context, selectableRegionState) {
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: selectableRegionState.contextMenuButtonItems,
        );
      },
      child: MarkdownBody(
        data: linkifyBareUrls(
          markdown.isEmpty ? l10n.emptyNotePlaceholder : note.markdown,
        ),
        onTapLink: (text, href, title) {
          if (href == null) return;
          openLink(href);
        },
        styleSheet: _markdownStyleSheet(context),
      ),
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
