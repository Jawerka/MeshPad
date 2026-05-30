import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/note.dart';
import '../models/note_folder.dart';
import '../models/note_meta.dart';
import '../models/sync_event.dart';
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

  Future<Note> createNote({
    String title = '',
    String markdown = '',
    String? author,
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
    final note = Note.fromMeta(meta: meta, markdown: markdown);
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
    return rows.map(_noteFromRow).toList();
  }

  Future<List<Note>> listTrash() async {
    final rows = await _db.watchTrashNotes();
    return rows.map(_noteFromRow).toList();
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

  /// Rebuild Drift index from file system (FS wins).
  Future<int> reconcileFromFilesystem() async {
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

  Note _noteFromRow(NoteRow row) => Note(
        id: row.id,
        title: row.title,
        markdown: row.markdown,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        author: row.author,
        deleted: row.deleted,
        deletedAt: row.deletedAt,
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
