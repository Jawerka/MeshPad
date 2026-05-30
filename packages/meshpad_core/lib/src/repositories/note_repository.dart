import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/note_meta.dart';
import '../models/note_search_hit.dart';
import '../models/sync_event.dart';
import '../storage/attachment_storage.dart';
import '../storage/meshpad_paths.dart';
import '../storage/note_folder_repository.dart';

/// Coordinates file-system storage (source of truth) and Drift index.
class NoteRepository {
  NoteRepository({
    required MeshPadPaths paths,
    required NoteFolderRepository fs,
    required MeshPadDatabase db,
    required this.defaultAuthor,
    Uuid? uuid,
  })  : _paths = paths,
        _fs = fs,
        _db = db,
        _uuid = uuid ?? const Uuid();

  final MeshPadPaths _paths;
  final NoteFolderRepository _fs;
  final MeshPadDatabase _db;
  final Uuid _uuid;
  final String defaultAuthor;

  MeshPadPaths get paths => _paths;

  Future<Note> createNote({
    String title = '',
    String markdown = '',
    String? author,
    List<String> attachmentPaths = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final meta = NoteMeta(
      schemaVersion: NoteMeta.currentSchemaVersion,
      id: id,
      title: title,
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
    for (final path in attachmentPaths) {
      attachments.add(
        await copyAttachmentIntoNote(
          attachmentsDir: _paths.attachmentsDir(id),
          sourcePath: path,
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
    await _enqueue(SyncEvent.opUpsert, id);
    return note;
  }

  Future<Note?> getNote(String id) async {
    final folder = await _fs.read(id);
    if (folder == null) return null;
    return Note.fromMeta(meta: folder.meta, markdown: folder.markdown);
  }

  Future<List<Note>> listNotes({
    bool includeDeleted = false,
    NoteSort sort = NoteSort.createdAt,
  }) async {
    final query = _db.select(_db.notes);
    if (!includeDeleted) {
      query.where((t) => t.deleted.equals(false));
    }
    switch (sort) {
      case NoteSort.createdAt:
        query.orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
      case NoteSort.updatedAt:
        query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    }
    final rows = await query.get();
    return _notesFromRows(rows);
  }

  Future<List<Note>> listTrash() async {
    final rows = await _db.watchTrashNotes();
    return _notesFromRows(rows);
  }

  Future<List<NoteSearchHit>> searchNotes(String query, {int limit = 50}) async {
    final hits = await _db.searchFts(query, limit: limit);
    if (hits.isEmpty) return [];

    final ids = hits.map((h) => h.noteId).toList();
    final rows = await (_db.select(_db.notes)..where((t) => t.id.isIn(ids))).get();
    final notesById = {for (final n in await _notesFromRows(rows)) n.id: n};

    return [
      for (final hit in hits)
        if (notesById.containsKey(hit.noteId))
          NoteSearchHit(note: notesById[hit.noteId]!, snippet: hit.snippet),
    ];
  }

  Future<Note> addAttachment(String id, String sourceFilePath) async {
    final existing = await getNote(id);
    if (existing == null) {
      throw StateError('Note not found: $id');
    }
    if (existing.deleted) {
      throw StateError('Cannot attach to deleted note: $id');
    }

    final attachment = await copyAttachmentIntoNote(
      attachmentsDir: _paths.attachmentsDir(id),
      sourcePath: sourceFilePath,
    );

    final updated = existing.copyWith(
      attachments: [...existing.attachments, attachment],
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(updated);
    return updated;
  }

  String attachmentPath(String noteId, String fileName) =>
      _paths.attachmentFile(noteId, fileName);

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
      title: title ?? existing.title,
      markdown: markdown ?? existing.markdown,
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(updated);
    return updated;
  }

  Future<void> deleteNote(String id) async {
    final existing = await getNote(id);
    if (existing == null || existing.deleted) return;

    final now = DateTime.now().toUtc();
    final deleted = existing.copyWith(deleted: true, deletedAt: now, updatedAt: now);
    await _persist(deleted);
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
    await _persist(restored);
    await _enqueue(SyncEvent.opUpsert, id);
  }

  /// Permanently removes notes in trash older than [ttl].
  Future<int> purgeExpiredTrash({Duration ttl = const Duration(days: 7)}) async {
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

  /// Rebuild Drift index from file system (FS wins).
  Future<int> reconcileFromFilesystem() async {
    await purgeExpiredTrash();
    final ids = await _fs.listNoteIds(includeDeleted: true);
    var count = 0;
    for (final id in ids) {
      final folder = await _fs.read(id);
      if (folder == null) continue;
      final note = Note.fromMeta(meta: folder.meta, markdown: folder.markdown);
      await _indexNote(note);
      count++;
    }
    return count;
  }

  Future<void> _purgeNote(String id) async {
    await _fs.deleteNoteFolder(id);
    await _db.deleteNoteRow(id);
    await _enqueue(SyncEvent.opPurge, id);
  }

  Future<void> _persist(Note note) async {
    final folder = NoteFolder(
      path: _paths.noteDir(note.id),
      meta: note.toMeta(),
      markdown: note.markdown,
    );
    await _fs.write(folder);
    await _indexNote(note);
    await _enqueue(SyncEvent.opUpsert, note.id);
  }

  Future<void> _indexNote(Note note) async {
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
  }

  Future<void> _enqueue(String operation, String noteId) {
    return _db.enqueueSync(
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
      );
}

/// Factory for a fully wired [NoteRepository] at [dataDir].
NoteRepository createNoteRepository({
  required String dataDir,
  required String defaultAuthor,
  MeshPadDatabase? database,
}) {
  final paths = MeshPadPaths(dataDir);
  final fs = NoteFolderRepository(notesRoot: paths.notesRoot);
  final db = database ?? createMeshPadDatabase(dataDir);
  return NoteRepository(
    paths: paths,
    fs: fs,
    db: db,
    defaultAuthor: defaultAuthor,
  );
}
