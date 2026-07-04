import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/attachment_copy_progress.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/note_meta.dart';
import '../models/note_tags.dart';
import '../models/note_head.dart';
import '../models/note_search_hit.dart';
import '../models/sync_event.dart';
import '../note_text.dart';
import '../storage/attachment_storage.dart';
import '../storage/attachment_thumbnails.dart';
import '../storage/note_fs_signatures.dart';
import '../storage/thumb_cache_eviction.dart';
import 'reconcile_background.dart';
import '../errors/meshpad_exception.dart';
import '../storage/meshpad_paths.dart';
import '../sync/attachment_upload.dart' as attachment_upload;
import '../sync/attachment_upload.dart'
    show AttachmentUploadResult, AttachmentUploadStatus;
import '../storage/note_folder_repository.dart';
import '../storage/note_history_store.dart';
import '../storage/note_operation_journal.dart';
import '../sync/sync_clock.dart';
import '../storage/note_conflict_copy.dart';
import '../sync/conflict_resolver.dart';
import '../sync/lww_merge.dart';
import '../sync/remote_note_snapshot.dart';

/// Coordinates file-system storage (source of truth) and Drift index.
class NoteRepository {
  NoteRepository({
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

  MeshPadPaths get paths => _paths;

  /// Revision numbers with FS snapshots under `history/<rev>/` (PLAN §7.2).
  Future<List<int>> listNoteHistoryRevisions(String noteId) =>
      _history.listRevisions(noteId);

  /// Reads a stored revision (`meta.json` + `note.md` only).
  Future<NoteFolder?> readNoteHistoryRevision(String noteId, int revision) =>
      _history.readRevision(noteId, revision);

  /// Restores title/markdown/tags from a history snapshot (PLAN §7.4, local only).
  Future<Note> restoreNoteHistoryRevision(String noteId, int revision) async {
    final folder = await _history.readRevision(noteId, revision);
    if (folder == null) {
      throw StateError('History revision $revision not found for $noteId');
    }
    final existing = await getNote(noteId);
    if (existing == null) {
      throw NoteNotFoundException(noteId);
    }
    final restored = existing.copyWith(
      title: folder.meta.title,
      markdown: folder.markdown,
      tags: folder.meta.tags,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(restored, operation: NoteOperationType.editNote);
    return (await getNote(noteId)) ?? restored;
  }

  Future<Note> createNote({
    String title = '',
    String markdown = '',
    String? author,
    List<String> attachmentPaths = const [],
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final resolvedTitle = resolveNoteTitle(
      currentTitle: '',
      markdown: markdown,
      explicitTitle: title.isEmpty ? null : title,
    );
    final finalTitle =
        resolvedTitle.isEmpty ? defaultTitleFromCreatedAt(now) : resolvedTitle;
    final meta = NoteMeta(
      schemaVersion: NoteMeta.currentSchemaVersion,
      id: id,
      title: finalTitle,
      createdAt: now,
      updatedAt: now,
      author: author ?? defaultAuthor,
    );
    final folder = NoteFolder(
      path: _paths.noteDir(id),
      meta: meta,
      markdown: markdown,
    );
    await _fs.write(folder);
    var attachments = <AttachmentMeta>[];
    for (var i = 0; i < attachmentPaths.length; i++) {
      attachments.add(
        await copyAttachmentIntoNote(
          attachmentsDir: _paths.attachmentsDir(id),
          sourcePath: attachmentPaths[i],
          onProgress: onAttachmentProgress,
          fileIndex: i + 1,
          fileCount: attachmentPaths.length,
        ),
      );
    }
    final note = Note.fromMeta(meta: meta, markdown: markdown).copyWith(
      attachments: attachments,
      updatedAt: attachments.isEmpty ? now : DateTime.now().toUtc(),
    );
    if (attachments.isNotEmpty) {
      await _fs.write(
        NoteFolder(
          path: _paths.noteDir(id),
          meta: note.toMeta(),
          markdown: markdown,
        ),
      );
    }
    await _indexNote(note);
    await _logOperation(
      NoteOperationType.createNote,
      noteId: note.id,
      device: note.author,
      revision: note.revision,
    );
    await _enqueue(SyncEvent.opUpsert, id);
    return note;
  }

  Future<List<NoteHead>> catalogHeads() async {
    final ids = await _fs.listNoteIds(includeDeleted: true);
    final heads = <NoteHead>[];
    for (final id in ids) {
      final folder = await _fs.read(id);
      if (folder == null) continue;
      heads.add(
        NoteHead(
          id: id,
          updatedAt: folder.meta.updatedAt,
          deleted: folder.meta.deleted,
        ),
      );
    }
    return heads;
  }

  Future<Note?> getNote(String id) async {
    final folder = await _fs.read(id);
    if (folder == null) return null;
    return Note.fromMeta(meta: folder.meta, markdown: folder.markdown);
  }

  /// Active notes with [updatedAt] >= [since] (PLAN §11.6.2 Web catch-up).
  Future<List<Note>> listNotesUpdatedSince(
    DateTime since, {
    NoteSort sort = NoteSort.updatedAt,
    String? tag,
  }) async {
    final normalizedTag = tag == null ? null : normalizeTag(tag);
    final query = _db.select(_db.notes)
      ..where((t) {
        var expr =
            t.deleted.equals(false) & t.updatedAt.isBiggerOrEqualValue(since);
        if (normalizedTag != null) {
          expr = expr & t.tags.like('%"$normalizedTag"%');
        }
        return expr;
      });
    switch (sort) {
      case NoteSort.createdAt:
        query.orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
      case NoteSort.updatedAt:
        query.orderBy([(t) => OrderingTerm.asc(t.updatedAt)]);
    }
    return _notesFromRows(await query.get());
  }

  Future<List<Note>> listNotes({
    bool includeDeleted = false,
    NoteSort sort = NoteSort.createdAt,
    String? tag,
  }) async {
    final normalizedTag = tag == null ? null : normalizeTag(tag);
    final query = _db.select(_db.notes);
    query.where((t) {
      if (includeDeleted && normalizedTag == null) return const Constant(true);
      var expr =
          includeDeleted ? const Constant(true) : t.deleted.equals(false);
      if (normalizedTag != null) {
        expr = expr & t.tags.like('%"$normalizedTag"%');
      }
      return expr;
    });
    switch (sort) {
      case NoteSort.createdAt:
        query.orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
      case NoteSort.updatedAt:
        query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    }
    final rows = await query.get();
    return _notesFromRows(rows);
  }

  /// Active notes count (non-deleted).
  Future<int> countActiveNotes({String? tag}) async {
    if (tag == null) {
      final countExp = _db.notes.id.count();
      final query = _db.selectOnly(_db.notes)
        ..addColumns([countExp])
        ..where(_db.notes.deleted.equals(false));
      final row = await query.getSingle();
      return row.read(countExp) ?? 0;
    }
    final normalized = normalizeTag(tag);
    if (normalized == null) return 0;
    final pattern = '%"$normalized"%';
    final countExp = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)
      ..addColumns([countExp])
      ..where(
        _db.notes.deleted.equals(false) & _db.notes.tags.like(pattern),
      );
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Slice of active notes in ascending order for [sort].
  Future<List<Note>> listNotesSlice({
    required int offset,
    int limit = 40,
    NoteSort sort = NoteSort.createdAt,
    String? tag,
  }) async {
    final normalizedTag = tag == null ? null : normalizeTag(tag);
    final query = _db.select(_db.notes)
      ..where((t) {
        var expr = t.deleted.equals(false);
        if (normalizedTag != null) {
          expr = expr & t.tags.like('%"$normalizedTag"%');
        }
        return expr;
      });
    switch (sort) {
      case NoteSort.createdAt:
        query.orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
      case NoteSort.updatedAt:
        query.orderBy([(t) => OrderingTerm.asc(t.updatedAt)]);
    }
    query.limit(limit, offset: offset);
    return _notesFromRows(await query.get());
  }

  Future<List<String>> listDistinctTags() => _db.listDistinctTags();

  Future<Note> setNoteTags(String id, List<String> tags) async {
    final existing = await getNote(id);
    if (existing == null) {
      throw NoteNotFoundException(id);
    }
    final updated = existing.copyWith(
      tags: normalizeTags(tags),
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(updated, operation: NoteOperationType.editNote);
    return updated;
  }

  Future<List<Note>> listTrash() async {
    final rows = await _db.watchTrashNotes();
    return _notesFromRows(rows);
  }

  Future<List<NoteSearchHit>> searchNotes(String query,
      {int limit = 50}) async {
    final hits = await _db.searchFts(query, limit: limit);
    if (hits.isEmpty) return [];

    final ids = hits.map((h) => h.noteId).toList();
    final rows =
        await (_db.select(_db.notes)..where((t) => t.id.isIn(ids))).get();
    final notesById = {for (final n in await _notesFromRows(rows)) n.id: n};

    return [
      for (final hit in hits)
        if (notesById.containsKey(hit.noteId))
          NoteSearchHit(note: notesById[hit.noteId]!, snippet: hit.snippet),
    ];
  }

  Future<Note> addAttachment(
    String id,
    String sourceFilePath, {
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    final existing = await getNote(id);
    if (existing == null) {
      throw NoteNotFoundException(id);
    }
    if (existing.deleted) {
      throw NoteDeletedException(id);
    }

    final attachment = await copyAttachmentIntoNote(
      attachmentsDir: _paths.attachmentsDir(id),
      sourcePath: sourceFilePath,
      onProgress: onAttachmentProgress,
    );

    final updated = existing.copyWith(
      attachments: [...existing.attachments, attachment],
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(updated, operation: NoteOperationType.editNote);
    return updated;
  }

  Future<Note> addAttachmentFromBytes(
    String id, {
    required String fileName,
    required List<int> bytes,
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    final existing = await getNote(id);
    if (existing == null) {
      throw NoteNotFoundException(id);
    }
    if (existing.deleted) {
      throw NoteDeletedException(id);
    }

    final attachment = await createAttachmentFromBytes(
      attachmentsDir: _paths.attachmentsDir(id),
      preferredName: fileName,
      bytes: bytes,
      onProgress: onAttachmentProgress,
    );

    final updated = existing.copyWith(
      attachments: [...existing.attachments, attachment],
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(updated, operation: NoteOperationType.editNote);
    return updated;
  }

  String attachmentPath(String noteId, String fileName) =>
      _paths.attachmentFile(noteId, fileName);

  Future<bool> attachmentMatches(String noteId, AttachmentMeta meta) {
    return attachmentFileMatches(
      File(attachmentPath(noteId, meta.name)),
      meta,
    );
  }

  Future<void> storeRemoteAttachment(
    String noteId,
    AttachmentMeta meta,
    List<int> bytes,
  ) async {
    await writeAttachmentBytes(
      attachmentsDir: _paths.attachmentsDir(noteId),
      meta: meta,
      bytes: bytes,
    );
  }

  Future<AttachmentUploadStatus?> attachmentUploadStatus(
    String noteId,
    String fileName,
  ) async {
    final note = await getNote(noteId);
    if (note == null) return null;

    AttachmentMeta? meta;
    for (final item in note.toMeta().attachments) {
      if (item.name == fileName) {
        meta = item;
        break;
      }
    }
    if (meta == null) return null;

    return attachment_upload.readAttachmentUploadStatus(
      attachmentsDir: _paths.attachmentsDir(noteId),
      fileName: fileName,
      meta: meta,
    );
  }

  Future<AttachmentUploadResult> receiveAttachmentUploadChunk({
    required String noteId,
    required String fileName,
    required int offset,
    required int totalSize,
    required String sha256,
    required List<int> bytes,
  }) async {
    final note = await getNote(noteId);
    if (note == null) {
      throw StateError('note not found');
    }

    AttachmentMeta? meta;
    for (final item in note.toMeta().attachments) {
      if (item.name == fileName) {
        meta = item;
        break;
      }
    }
    if (meta == null) {
      throw StateError('attachment not in note meta');
    }

    return attachment_upload.receiveAttachmentUploadChunk(
      attachmentsDir: _paths.attachmentsDir(noteId),
      meta: meta,
      offset: offset,
      totalSize: totalSize,
      sha256: sha256,
      bytes: bytes,
    );
  }

  Future<List<int>?> readAttachmentBytes(String noteId, String fileName) async {
    final file = File(attachmentPath(noteId, fileName));
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<int> pendingOutboxCount() => _db.pendingOutboxCount();

  Future<Set<String>> pendingOutboxNoteIds() => _db.pendingOutboxNoteIds();

  Future<List<SyncEvent>> listOutbox() async {
    final rows = await _db.listOutboxEntries();
    return rows
        .map(
          (row) => SyncEvent(
            id: row.id,
            entityType: row.entityType,
            entityId: row.entityId,
            operation: row.operation,
            payload: row.payload,
            createdAt: row.createdAt,
            retryCount: row.retryCount,
          ),
        )
        .toList();
  }

  Future<void> removeOutboxEntry(int id) => _db.removeOutboxEntry(id);

  Future<void> incrementOutboxRetry(int id) => _db.incrementOutboxRetry(id);

  /// Removes outbox rows for notes authored on other devices (legacy bug).
  Future<int> purgeMisfiledRemoteOutbox({
    required Set<String> localAuthorLabels,
  }) async {
    final outbox = await listOutbox();
    var removed = 0;
    for (final entry in outbox) {
      if (entry.entityType != SyncEvent.entityNote) continue;
      final note = await getNote(entry.entityId);
      if (note == null) continue;
      if (!localAuthorLabels.contains(note.author.trim())) {
        await removeOutboxEntry(entry.id);
        removed++;
      }
    }
    return removed;
  }

  /// Drops outbox rows that exceeded retry limit (legacy false errors).
  Future<int> purgeExhaustedOutboxEntries({required int maxRetries}) async {
    final outbox = await listOutbox();
    var removed = 0;
    for (final entry in outbox) {
      if (entry.retryCount >= maxRetries) {
        await removeOutboxEntry(entry.id);
        removed++;
      }
    }
    return removed;
  }

  Future<NoteApplyResult> applyRemoteMerge(
    NoteMeta remoteMeta,
    String remoteMarkdown,
  ) async {
    final local = await getNote(remoteMeta.id);
    inspectRemoteNoteTimestamp(
      noteId: remoteMeta.id,
      remoteUpdatedAt: remoteMeta.updatedAt,
      localUpdatedAt: local?.updatedAt,
    );

    if (local == null) {
      final note = Note.fromMeta(meta: remoteMeta, markdown: remoteMarkdown);
      await _persist(note, enqueueOutbox: false);
      return NoteApplyResult.applied;
    }

    final outcome = resolveNoteConflict(
      local: local.toMeta(),
      remote: remoteMeta,
      localMarkdown: local.markdown,
      remoteMarkdown: remoteMarkdown,
    );

    switch (outcome) {
      case MergeOutcome.unchanged:
        return NoteApplyResult.unchanged;
      case MergeOutcome.appliedLocal:
        return NoteApplyResult.skippedLocalNewer;
      case MergeOutcome.createdConflictCopy:
        await NoteConflictCopyStore(noteDir: _paths.noteDir(local.id)).write(
          noteId: local.id,
          remoteMeta: remoteMeta,
          remoteMarkdown: remoteMarkdown,
        );
        return NoteApplyResult.conflictCopyCreated;
      case MergeOutcome.appliedRemote:
        final merged = mergeNoteMeta(local.toMeta(), remoteMeta)!;
        final note = Note.fromMeta(meta: merged, markdown: remoteMarkdown);
        await _persist(note, enqueueOutbox: false);
        return NoteApplyResult.applied;
    }
  }

  Future<List<NoteConflictCopy>> listConflictCopies(String noteId) =>
      NoteConflictCopyStore(noteDir: _paths.noteDir(noteId)).list();

  Future<({String title, String markdown})?> readConflictCopy(
    String noteId,
    String fileName,
  ) async {
    final parsed =
        await NoteConflictCopyStore(noteDir: _paths.noteDir(noteId)).read(
      fileName,
    );
    if (parsed == null) return null;
    return (title: parsed.title, markdown: parsed.markdown);
  }

  /// Replaces the note with a conflict copy and removes conflict files.
  Future<void> applyConflictCopy(String noteId, String fileName) async {
    final store = NoteConflictCopyStore(noteDir: _paths.noteDir(noteId));
    final parsed = await store.read(fileName);
    if (parsed == null) return;

    final existing = await getNote(noteId);
    if (existing == null) return;

    final updated = existing.copyWith(
      title: parsed.title.isNotEmpty ? parsed.title : existing.title,
      markdown: parsed.markdown,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(updated, operation: NoteOperationType.editNote);
    await store.deleteAll();
  }

  Future<void> dismissConflictCopies(String noteId) async {
    await NoteConflictCopyStore(noteDir: _paths.noteDir(noteId)).deleteAll();
  }

  Future<Note> updateNote(
    String id, {
    String? title,
    String? markdown,
  }) async {
    final existing = await getNote(id);
    if (existing == null) {
      throw StateError('Note not found: $id');
    }
    if (existing.deleted) {
      throw StateError('Cannot edit deleted note: $id');
    }

    final updated = existing.copyWith(
      title: resolveNoteTitle(
        currentTitle: existing.title,
        markdown: markdown ?? existing.markdown,
        explicitTitle: title,
      ),
      markdown: markdown ?? existing.markdown,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(
      updated,
      operation: NoteOperationType.editNote,
    );
    return (await getNote(id)) ?? updated;
  }

  Future<void> deleteNote(String id) async {
    final existing = await getNote(id);
    if (existing == null || existing.deleted) return;

    final now = DateTime.now().toUtc();
    final deleted =
        existing.copyWith(deleted: true, deletedAt: now, updatedAt: now);
    await _persist(
      deleted,
      operation: NoteOperationType.deleteNote,
    );
    await _enqueue(SyncEvent.opDelete, id);
  }

  Future<void> restoreNote(String id) async {
    final existing = await getNote(id);
    if (existing == null || !existing.deleted) return;

    final now = DateTime.now().toUtc();
    final restored = existing.copyWith(
      deleted: false,
      deletedAt: null,
      updatedAt: now,
    );
    await _persist(
      restored,
      operation: NoteOperationType.restoreNote,
    );
    await _enqueue(SyncEvent.opUpsert, id);
  }

  /// Permanently removes notes in trash older than [ttl].
  Future<int> purgeExpiredTrash(
      {Duration ttl = const Duration(days: 7)}) async {
    final cutoff = DateTime.now().toUtc().subtract(ttl);
    final trash = await listTrash();
    var purged = 0;
    for (final note in trash) {
      final deletedAt = note.deletedAt;
      if (deletedAt != null && deletedAt.isBefore(cutoff)) {
        await _purgeNote(note.id);
        purged++;
      }
    }
    return purged;
  }

  /// Permanently removes every note currently in trash.
  Future<int> emptyTrash() async {
    final trash = await listTrash();
    for (final note in trash) {
      await _purgeNote(note.id);
    }
    return trash.length;
  }

  /// Rebuild Drift index from file system (FS wins).
  ///
  /// When [thumbCacheMaxMb] is set, evicts oldest `.thumbs/` files over the budget
  /// after rebuilding missing previews (PLAN §11.5.4).
  Future<int> reconcileFromFilesystem({
    int? thumbCacheMaxMb,
    int isolateNoteThreshold = reconcileIsolateNoteThreshold,
  }) async {
    await purgeExpiredTrash();

    final dirIds = await _fs.listNoteDirectoryIds();
    if (dirIds.length > isolateNoteThreshold) {
      return runReconcileInIsolate(
        dataDir: _paths.root,
        defaultAuthor: defaultAuthor,
        thumbCacheMaxMb: thumbCacheMaxMb,
      );
    }

    final dirIdSet = dirIds.toSet();

    for (final id in await _db.listAllNoteIds()) {
      if (!dirIdSet.contains(id)) {
        await _db.deleteNoteRow(id);
      }
    }

    var count = 0;
    for (final id in dirIds) {
      final signatures = await readNoteFsSignatures(_paths, id);
      if (signatures == null) continue;

      final cached = await _db.getNoteFsSignatures(id);
      if (cached != null &&
          cached.meta != null &&
          cached.md != null &&
          signatures.matches(
            NoteFsSignatures(
              metaModifiedAt: cached.meta!,
              markdownModifiedAt: cached.md!,
              attachmentsModifiedAt: cached.attachments,
            ),
          )) {
        final meta = await _fs.readMeta(id);
        if (meta != null && await _driftIndexMatchesMeta(id, meta)) {
          continue;
        }
      }

      final folder = await _fs.read(id);
      if (folder == null) continue;
      var meta = folder.meta;
      final derivedTitle = titleFromMarkdown(folder.markdown);
      if (meta.title.trim().isEmpty && derivedTitle.isNotEmpty) {
        meta = NoteMeta(
          schemaVersion: meta.schemaVersion,
          id: meta.id,
          title: derivedTitle,
          createdAt: meta.createdAt,
          updatedAt: meta.updatedAt,
          author: meta.author,
          deleted: meta.deleted,
          deletedAt: meta.deletedAt,
          attachments: meta.attachments,
        );
        await _fs.write(
          NoteFolder(path: folder.path, meta: meta, markdown: folder.markdown),
        );
      }
      final note = Note.fromMeta(meta: meta, markdown: folder.markdown);
      await _indexNote(note, fsSignatures: signatures);
      count++;
    }
    await rebuildMissingImageThumbnails(_paths);
    if (thumbCacheMaxMb != null && thumbCacheMaxMb > 0) {
      await evictThumbCache(
        notesRoot: _paths.notesRoot,
        maxBytes: thumbCacheMaxMb * 1024 * 1024,
      );
    }
    return count;
  }

  /// Generates missing `.thumbs/` previews for indexed image attachments.
  Future<int> rebuildMissingImageThumbnails(MeshPadPaths paths) async {
    var rebuilt = 0;
    final ids = await _fs.listNoteIds(includeDeleted: false);
    for (final id in ids) {
      final note = await getNote(id);
      if (note == null) continue;
      for (final attachment in note.attachments) {
        if (!isImageAttachment(attachment)) continue;
        final attachmentPath = paths.attachmentFile(id, attachment.name);
        final thumbPath = paths.thumbFile(id, attachment.name);
        if (!await File(attachmentPath).exists()) continue;
        if (await File(thumbPath).exists()) continue;
        await ensureImageThumbnail(
          attachmentPath: attachmentPath,
          thumbsDir: paths.thumbsDir(id),
          attachmentName: attachment.name,
        );
        rebuilt++;
      }
    }
    return rebuilt;
  }

  static bool _sameUtcInstant(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    // Drift/SQLite stores datetimes at second precision; meta.json keeps full ISO.
    return a.toUtc().millisecondsSinceEpoch ~/ 1000 ==
        b.toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  Future<bool> _driftIndexMatchesMeta(String id, NoteMeta meta) async {
    final row = await (_db.select(_db.notes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return false;
    return _sameUtcInstant(row.updatedAt, meta.updatedAt) &&
        row.deleted == meta.deleted &&
        _sameUtcInstant(row.deletedAt, meta.deletedAt);
  }

  Future<void> _purgeNote(String id) async {
    await _logOperation(
      NoteOperationType.purgeNote,
      noteId: id,
      device: defaultAuthor,
    );
    await _fs.deleteNoteFolder(id);
    await _db.deleteNoteRow(id);
    await _enqueue(SyncEvent.opPurge, id);
  }

  Future<void> _logOperation(
    NoteOperationType type, {
    required String noteId,
    required String device,
    int? revision,
    bool? deleted,
  }) {
    return _operations.record(
      type: type,
      noteId: noteId,
      device: device,
      revision: revision,
      deleted: deleted,
    );
  }

  Future<void> _persist(
    Note note, {
    bool enqueueOutbox = true,
    NoteOperationType? operation,
  }) async {
    var meta = note.toMeta();
    if (enqueueOutbox) {
      meta = meta.copyWith(revision: meta.revision + 1);
    }
    final folder = NoteFolder(
      path: _paths.noteDir(note.id),
      meta: meta,
      markdown: note.markdown,
    );
    await _fs.write(folder);
    final indexed =
        enqueueOutbox ? note.copyWith(revision: meta.revision) : note;
    await _indexNote(indexed);
    if (enqueueOutbox) {
      if (operation != null) {
        await _logOperation(
          operation,
          noteId: note.id,
          device: note.author,
          revision: indexed.revision,
          deleted: note.deleted,
        );
        await _history.maybeSnapshot(indexed);
      }
      await _enqueue(SyncEvent.opUpsert, note.id);
    }
  }

  Future<void> _indexNote(
    Note note, {
    NoteFsSignatures? fsSignatures,
  }) async {
    final signatures =
        fsSignatures ?? await readNoteFsSignatures(_paths, note.id);
    await _db.upsertNoteRow(
      id: note.id,
      title: note.title,
      author: note.author,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      deleted: note.deleted,
      deletedAt: note.deletedAt,
      previewSnippet: previewSnippetFromMarkdown(note.markdown),
      markdown: note.markdown,
      tags: note.tags,
      fsMetaModifiedAt: signatures?.normalized().metaModifiedAt,
      fsMarkdownModifiedAt: signatures?.normalized().markdownModifiedAt,
      fsAttachmentsModifiedAt: signatures?.normalized().attachmentsModifiedAt,
    );
    await _db.replaceAttachments(
      note.id,
      note.attachments
          .map(
            (a) => NoteAttachmentsCompanion.insert(
              noteId: note.id,
              name: a.name,
              size: Value(a.size),
              mime: Value(a.mime),
              sha256: Value(a.sha256),
            ),
          )
          .toList(),
    );
    if (note.deleted) {
      await _db.removeNoteFts(note.id);
    } else {
      await _db.indexNoteFts(
        note.id,
        note.title,
        note.markdown,
        attachmentNames: note.attachments.map((attachment) => attachment.name),
        tags: note.tags,
      );
    }
  }

  Future<void> _enqueue(String operation, String noteId) async {
    await _db.removeOutboxEntries(
      entityType: SyncEvent.entityNote,
      entityId: noteId,
      operation: operation,
    );
    await _db.enqueueSync(
      entityType: SyncEvent.entityNote,
      entityId: noteId,
      operation: operation,
    );
  }

  Future<List<Note>> _notesFromRows(List<NoteRow> rows) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r.id).toList();
    final attachmentsMap = await _db.attachmentsByNoteIds(ids);
    return rows
        .map(
          (row) => _noteFromRow(
            row,
            attachmentsMap[row.id] ?? const [],
          ),
        )
        .toList();
  }

  Note _noteFromRow(NoteRow row, List<AttachmentMeta> attachments) => Note(
        id: row.id,
        title: row.title,
        markdown: row.markdown,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        author: row.author,
        deleted: row.deleted,
        deletedAt: row.deletedAt,
        attachments: attachments,
        tags: parseTagsJson(row.tags),
      );
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
