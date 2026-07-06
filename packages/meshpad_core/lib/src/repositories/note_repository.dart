import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../errors/meshpad_exception.dart';
import '../models/attachment_copy_progress.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/note_head.dart';
import '../models/note_meta.dart';
import '../models/note_search_hit.dart';
import '../models/note_tags.dart';
import '../models/sync_event.dart';
import '../note_text.dart';
import '../storage/attachment_storage.dart';
import '../storage/attachment_thumbnails.dart';
import '../storage/meshpad_paths.dart';
import '../storage/note_conflict_copy.dart';
import '../storage/note_folder_repository.dart';
import '../storage/note_fs_signatures.dart';
import '../storage/note_history_store.dart';
import '../storage/note_operation_journal.dart';
import '../storage/thumb_cache_eviction.dart';
import '../sync/attachment_upload.dart' as attachment_upload;
import '../sync/attachment_upload.dart'
    show AttachmentUploadResult, AttachmentUploadStatus;
import '../sync/conflict_resolver.dart';
import '../sync/lww_merge.dart';
import '../sync/remote_note_snapshot.dart';
import '../sync/sync_clock.dart';
import 'reconcile_background.dart';

part 'note_repository_internals.dart';
part 'note_repository_crud.dart';
part 'note_repository_attachments.dart';
part 'note_repository_outbox.dart';
part 'note_repository_reconcile.dart';

/// Shared state for [NoteRepository] mixins (Wave 2 split).
abstract class _NoteRepositoryHost {
  _NoteRepositoryHost({
    required MeshPadPaths paths,
    required NoteFolderRepository fs,
    required MeshPadDatabase db,
    required this.defaultAuthor,
    Uuid? uuid,
    NoteOperationJournal? operationJournal,
    NoteHistoryStore? historyStore,
  })  : _paths = paths,
        _fs = fs,
        _db = db,
        _uuid = uuid ?? const Uuid(),
        _operations = operationJournal ?? NoteOperationJournal(paths: paths),
        _history = historyStore ?? NoteHistoryStore(paths: paths);

  final MeshPadPaths _paths;
  final NoteFolderRepository _fs;
  final MeshPadDatabase _db;
  final Uuid _uuid;
  final NoteOperationJournal _operations;
  final NoteHistoryStore _history;
  final String defaultAuthor;
}

/// Coordinates file-system storage (source of truth) and Drift index.
class NoteRepository extends _NoteRepositoryHost
    with
        _NoteRepositoryInternals,
        _NoteRepositoryCrud,
        _NoteRepositoryAttachments,
        _NoteRepositoryOutbox,
        _NoteRepositoryReconcile {
  NoteRepository({
    required super.paths,
    required super.fs,
    required super.db,
    required super.defaultAuthor,
    super.uuid,
    super.operationJournal,
    super.historyStore,
  });

  MeshPadPaths get paths => _paths;
}

/// Factory for a fully wired [NoteRepository] at [dataDir].
NoteRepository createNoteRepository({
  required String dataDir,
  required String defaultAuthor,
  MeshPadDatabase? database,
  NoteOperationJournal? operationJournal,
  NoteHistoryStore? historyStore,
}) {
  final paths = MeshPadPaths(dataDir);
  final fs = NoteFolderRepository(notesRoot: paths.notesRoot);
  final db = database ?? createMeshPadDatabase(dataDir);
  return NoteRepository(
    paths: paths,
    fs: fs,
    db: db,
    defaultAuthor: defaultAuthor,
    operationJournal: operationJournal,
    historyStore: historyStore,
  );
}
