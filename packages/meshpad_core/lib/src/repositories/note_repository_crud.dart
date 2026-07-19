part of 'note_repository.dart';

mixin _NoteRepositoryCrud on _NoteRepositoryHost, _NoteRepositoryInternals {
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
    final finalTitle = resolvedTitle;
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
    final ids = await _fs.listNoteDirectoryIds();
    final heads = <NoteHead>[];
    for (final id in ids) {
      final meta = await _fs.readMeta(id);
      if (meta == null) continue;
      heads.add(
        NoteHead(
          id: id,
          updatedAt: meta.updatedAt,
          deleted: meta.deleted,
          purged: meta.purged,
        ),
      );
    }
    return heads;
  }

  /// Reads `meta.json` for sync (includes purge tombstones).
  Future<NoteMeta?> readNoteMeta(String id) => _fs.readMeta(id);

  Future<Note?> getNote(String id) async {
    final meta = await _fs.readMeta(id);
    if (meta == null || meta.purged) return null;
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
    final deleted = existing.copyWith(
      deleted: true,
      deletedAt: now,
      updatedAt: now,
      attachments: const [],
    );
    await _fs.clearAttachmentDirs(id);
    // Single opUpsert (deleted:true); push is catalog-driven — no opDelete stack.
    await _persist(
      deleted,
      operation: NoteOperationType.deleteNote,
    );
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
}
