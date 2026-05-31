import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../models/note_meta.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Notes, NoteAttachments, SyncOutbox, Devices])
class MeshPadDatabase extends _$MeshPadDatabase {
  MeshPadDatabase(super.e);

  MeshPadDatabase.inMemory() : super(NativeDatabase.memory());

  /// False when the linked SQLite build has no FTS5 (e.g. some test runtimes).
  bool ftsAvailable = false;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          ftsAvailable = await _tryCreateFtsTable();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            ftsAvailable = await _tryCreateFtsTable();
            if (ftsAvailable) {
              await rebuildAllFts();
            }
          }
        },
      );

  Future<bool> _tryCreateFtsTable() async {
    try {
      await customStatement(
        'CREATE VIRTUAL TABLE IF NOT EXISTS note_fts '
        "USING fts5(note_id UNINDEXED, body, tokenize='unicode61')",
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> upsertNoteRow({
    required String id,
    required String title,
    required String author,
    required DateTime createdAt,
    required DateTime updatedAt,
    required bool deleted,
    DateTime? deletedAt,
    required String previewSnippet,
    required String markdown,
  }) async {
    await into(notes).insertOnConflictUpdate(
      NotesCompanion.insert(
        id: id,
        title: Value(title),
        author: Value(author),
        createdAt: createdAt,
        updatedAt: updatedAt,
        deleted: Value(deleted),
        deletedAt: Value(deletedAt),
        previewSnippet: Value(previewSnippet),
        markdown: Value(markdown),
      ),
    );
    if (!deleted && ftsAvailable) {
      await indexNoteFts(id, markdown);
    } else if (deleted && ftsAvailable) {
      await removeNoteFts(id);
    }
  }

  Future<void> indexNoteFts(String noteId, String markdown) async {
    if (!ftsAvailable) return;
    await customStatement(
      'DELETE FROM note_fts WHERE note_id = ?',
      [noteId],
    );
    await customStatement(
      'INSERT INTO note_fts (note_id, body) VALUES (?, ?)',
      [noteId, markdown],
    );
  }

  Future<void> removeNoteFts(String noteId) async {
    if (!ftsAvailable) return;
    await customStatement('DELETE FROM note_fts WHERE note_id = ?', [noteId]);
  }

  Future<void> rebuildAllFts() async {
    if (!ftsAvailable) return;
    await customStatement('DELETE FROM note_fts');
    final rows = await select(notes).get();
    for (final row in rows) {
      if (!row.deleted) {
        await indexNoteFts(row.id, row.markdown);
      }
    }
  }

  Future<List<({String noteId, String snippet})>> searchFts(
    String query, {
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    if (ftsAvailable) {
      return _searchFtsNative(trimmed, limit: limit);
    }
    return _searchLike(trimmed, limit: limit);
  }

  Future<List<({String noteId, String snippet})>> _searchFtsNative(
    String query, {
    required int limit,
  }) async {
    final term = escapeFtsQuery(query);
    if (term.isEmpty) return [];

    final rows = await customSelect(
      '''
      SELECT f.note_id AS note_id,
             snippet(note_fts, 1, '', '', '…', 48) AS snippet
      FROM note_fts f
      INNER JOIN notes n ON n.id = f.note_id
      WHERE note_fts MATCH ? AND n.deleted = 0
      ORDER BY rank
      LIMIT ?
      ''',
      variables: [Variable.withString(term), Variable.withInt(limit)],
      readsFrom: {notes},
    ).get();

    return rows
        .map(
          (row) => (
            noteId: row.read<String>('note_id'),
            snippet: row.read<String>('snippet'),
          ),
        )
        .toList();
  }

  Future<List<({String noteId, String snippet})>> _searchLike(
    String query, {
    required int limit,
  }) async {
    final pattern = '%${query.replaceAll('%', '')}%';
    final rows = await (select(notes)
          ..where((t) => t.deleted.equals(false) & t.markdown.like(pattern))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit))
        .get();

    return rows
        .map(
          (row) => (
            noteId: row.id,
            snippet: previewSnippetFromMarkdown(row.markdown, maxLen: 48),
          ),
        )
        .toList();
  }

  Future<void> replaceAttachments(String noteId, List<NoteAttachmentsCompanion> rows) async {
    await (delete(noteAttachments)..where((t) => t.noteId.equals(noteId))).go();
    if (rows.isNotEmpty) {
      await batch((b) => b.insertAll(noteAttachments, rows));
    }
  }

  Future<Map<String, List<AttachmentMeta>>> attachmentsByNoteIds(
    List<String> noteIds,
  ) async {
    if (noteIds.isEmpty) return {};
    final rows = await (select(noteAttachments)
          ..where((t) => t.noteId.isIn(noteIds)))
        .get();
    final map = <String, List<AttachmentMeta>>{};
    for (final row in rows) {
      map.putIfAbsent(row.noteId, () => []).add(
            AttachmentMeta(
              name: row.name,
              size: row.size,
              mime: row.mime,
              sha256: row.sha256,
            ),
          );
    }
    return map;
  }

  Future<List<NoteRow>> watchActiveNotes() {
    return (select(notes)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<NoteRow>> watchTrashNotes() {
    return (select(notes)
          ..where((t) => t.deleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .get();
  }

  Future<void> deleteNoteRow(String id) async {
    await (delete(noteAttachments)..where((t) => t.noteId.equals(id))).go();
    await (delete(notes)..where((t) => t.id.equals(id))).go();
    if (ftsAvailable) {
      await removeNoteFts(id);
    }
  }

  Future<void> enqueueSync({
    required String entityType,
    required String entityId,
    required String operation,
    String? payload,
  }) {
    return into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: Value(payload),
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> removeOutboxEntries({
    required String entityType,
    required String entityId,
    required String operation,
  }) {
    return (delete(syncOutbox)
          ..where(
            (t) =>
                t.entityType.equals(entityType) &
                t.entityId.equals(entityId) &
                t.operation.equals(operation),
          ))
        .go();
  }

  Future<int> pendingOutboxCount() async {
    final count = syncOutbox.id.count();
    final row = await (selectOnly(syncOutbox)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<Set<String>> pendingOutboxNoteIds() async {
    final rows = await (select(syncOutbox)
          ..where((t) => t.entityType.equals('note')))
        .get();
    return rows.map((r) => r.entityId).toSet();
  }

  Future<List<SyncOutboxData>> listOutboxEntries() {
    return (select(syncOutbox)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> removeOutboxEntry(int id) async {
    await (delete(syncOutbox)..where((t) => t.id.equals(id))).go();
  }

  Future<void> incrementOutboxRetry(int id) async {
    final row = await (select(syncOutbox)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(retryCount: Value(row.retryCount + 1)),
    );
  }
}

String escapeFtsQuery(String raw) {
  final words = raw.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '';
  return words.map((w) => '"${w.replaceAll('"', '""')}"').join(' AND ');
}

LazyDatabase openMeshPadDatabase(String dataDir) {
  return LazyDatabase(() async {
    final indexDir = Directory(p.join(dataDir, 'index'));
    await indexDir.create(recursive: true);
    final file = File(p.join(indexDir.path, 'meshpad.db'));
    return NativeDatabase.createInBackground(file);
  });
}

MeshPadDatabase createMeshPadDatabase(String dataDir) {
  return MeshPadDatabase(openMeshPadDatabase(dataDir));
}

String previewSnippetFromMarkdown(String markdown, {int maxLen = 120}) {
  final collapsed = markdown.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= maxLen) return collapsed;
  return '${collapsed.substring(0, maxLen)}…';
}
