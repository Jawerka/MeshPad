import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../l10n/app_localizations.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/ui/meshpad_status_hint.dart';
import '../../core/ui/status_hint_provider.dart';
import 'note_conflict_sheet.dart';
import 'note_history_sheet.dart';
import 'note_tags_editor.dart';

/// Menu actions available on a feed note bubble.
List<PopupMenuEntry<String>> buildNoteContextMenuItems({
  required BuildContext context,
  required bool isTrash,
  required bool hasConflicts,
  required bool isWeb,
}) {
  final l10n = AppLocalizations.of(context);
  if (isTrash) {
    return [
      PopupMenuItem(
        value: 'restore',
        child: Text(l10n.noteMenuRestore),
      ),
    ];
  }
  return [
    if (hasConflicts)
      PopupMenuItem(
        value: 'conflicts',
        child: Text(l10n.noteMenuConflicts),
      ),
    PopupMenuItem(
      value: 'edit',
      child: Text(l10n.noteMenuEdit),
    ),
    PopupMenuItem(
      value: 'copy',
      child: Text(l10n.noteMenuCopyAll),
    ),
    if (!isWeb)
      PopupMenuItem(
        value: 'tags',
        child: Text(l10n.noteMenuTags),
      ),
    if (!isWeb)
      PopupMenuItem(
        value: 'history',
        child: Text(l10n.noteMenuHistory),
      ),
    PopupMenuItem(
      value: 'delete',
      child: Text(l10n.noteMenuTrash),
    ),
  ];
}

Future<void> handleNoteAction({
  required String action,
  required BuildContext context,
  required WidgetRef ref,
  required Note note,
  required VoidCallback onEdit,
  required String Function(Note note) copyAllText,
}) async {
  switch (action) {
    case 'edit':
      onEdit();
    case 'tags':
      final next = await showNoteTagsEditorDialog(
        context,
        initialTags: note.tags,
      );
      if (next == null || !context.mounted) return;
      await ref.read(notesListProvider.notifier).setNoteTags(note.id, next);
    case 'delete':
      await ref.read(notesListProvider.notifier).deleteNote(note.id);
    case 'restore':
      await ref.read(notesListProvider.notifier).restoreNote(note.id);
    case 'conflicts':
      await showNoteConflictSheet(context, ref, note);
    case 'history':
      await showNoteHistorySheet(context, ref, note);
    case 'copy':
      final text = copyAllText(note);
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) return;
      showMeshPadHint(
        context,
        AppLocalizations.of(context).noteMenuCopyAll,
        severity: StatusHintSeverity.success,
      );
  }
}

Future<void> showNoteContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<PopupMenuEntry<String>> items,
  required Future<void> Function(String action) onSelected,
}) async {
  if (items.isEmpty) return;
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: items,
  );
  if (action != null) {
    await onSelected(action);
  }
}
