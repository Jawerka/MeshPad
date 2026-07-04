import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../l10n/app_localizations.dart';
import '../../core/providers/notes_providers.dart';

Future<void> showNoteConflictSheet(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final l10n = AppLocalizations.of(context);
  final copies = await ref.read(noteRepositoryProvider.future).then(
        (repo) => repo.listConflictCopies(note.id),
      );
  if (!context.mounted || copies.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.noteConflictTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noteConflictBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final copy in copies)
                ListTile(
                  title: Text(copy.remoteTitle.isEmpty
                      ? l10n.noteConflictUntitled
                      : copy.remoteTitle),
                  subtitle: Text(
                    '${copy.remoteAuthor} · ${copy.savedAt.toLocal()}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final repo = await ref.read(noteRepositoryProvider.future);
                    final content = await repo.readConflictCopy(
                      note.id,
                      copy.fileName,
                    );
                    if (!context.mounted || content == null) return;
                    Navigator.pop(context);
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.noteConflictPreview),
                        content: SingleChildScrollView(
                          child: Text(content.markdown),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l10n.noteConflictClose),
                          ),
                          FilledButton(
                            onPressed: () async {
                              await repo.applyConflictCopy(
                                note.id,
                                copy.fileName,
                              );
                              ref.invalidate(notesListProvider);
                              ref.invalidate(
                                  noteConflictCopiesProvider(note.id));
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: Text(l10n.noteConflictUseRemote),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final repo = await ref.read(noteRepositoryProvider.future);
                  await repo.dismissConflictCopies(note.id);
                  ref.invalidate(noteConflictCopiesProvider(note.id));
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(l10n.noteConflictKeepMine),
              ),
            ],
          ),
        ),
      );
    },
  );
}
