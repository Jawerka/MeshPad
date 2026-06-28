import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../l10n/app_localizations.dart';
import '../../core/providers/notes_providers.dart';
import 'feed_screen.dart';
import 'note_history_diff.dart';

Future<void> showNoteHistorySheet(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final l10n = AppLocalizations.of(context);
  final repo = await ref.read(noteRepositoryProvider.future);
  final revisions = await repo.listNoteHistoryRevisions(note.id);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.noteHistoryTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noteHistoryBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (revisions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.noteHistoryEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: revisions.length,
                    itemBuilder: (context, index) {
                      final revision = revisions[revisions.length - 1 - index];
                      return ListTile(
                        title: Text(l10n.noteHistoryRevision(revision)),
                        subtitle: note.revision == revision
                            ? Text(l10n.noteHistoryCurrentRevision)
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openRevisionPreview(
                          context,
                          ref,
                          note: note,
                          revision: revision,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _openRevisionPreview(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
  required int revision,
}) async {
  final l10n = AppLocalizations.of(context);
  final repo = await ref.read(noteRepositoryProvider.future);
  final folder = await repo.readNoteHistoryRevision(note.id, revision);
  if (!context.mounted || folder == null) return;

  final snapshotMarkdown = folder.markdown;
  final savedAt = folder.meta.updatedAt;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(l10n.noteHistoryRevision(revision)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                formatNoteDate(savedAt.toLocal()),
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noteHistoryDiffLegend,
                style: Theme.of(ctx).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: NoteHistoryDiffView(
                  currentMarkdown: note.markdown,
                  snapshotMarkdown: snapshotMarkdown,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.noteHistoryClose),
          ),
          FilledButton(
            onPressed: () async {
              await repo.restoreNoteHistoryRevision(note.id, revision);
              ref.invalidate(notesListProvider);
              ref.invalidate(noteHistoryRevisionsProvider(note.id));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(ctx);
              }
            },
            child: Text(l10n.noteHistoryRestore),
          ),
        ],
      );
    },
  );
}
