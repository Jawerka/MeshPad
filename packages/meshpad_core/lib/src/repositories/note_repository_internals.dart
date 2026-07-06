part of 'note_repository.dart';

mixin _NoteRepositoryInternals on _NoteRepositoryHost {
  static bool _sameUtcInstant(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
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
