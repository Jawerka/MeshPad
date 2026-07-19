import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../models/note_meta.dart';
import '../models/note_tags.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Notes, NoteAttachments, SyncOutbox, Devices])
class MeshPadDatabase extends _$MeshPadDatabase {
  MeshPadDatabase(super.e);

  MeshPadDatabase.inMemory() : super(NativeDatabase.memory());

  /// False when the linked SQLite build has no FTS5 (e.g. some test runtimes).
  bool ftsAvailable = false;

  @override
  int get schemaVersion => 4;

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
          if (from < 3) {
            await m.addColumn(notes, notes.tags);
          }
          if (from < 4) {
            await m.addColumn(notes, notes.fsMetaModifiedAt);
            await m.addColumn(notes, notes.fsMarkdownModifiedAt);
            await m.addColumn(notes, notes.fsAttachmentsModifiedAt);
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
    List<String> tags = const [],
    DateTime? fsMetaModifiedAt,
    DateTime? fsMarkdownModifiedAt,
    DateTime? fsAttachmentsModifiedAt,
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
        tags: Value(encodeTagsJson(tags)),
        fsMetaModifiedAt: Value(fsMetaModifiedAt),
        fsMarkdownModifiedAt: Value(fsMarkdownModifiedAt),
        fsAttachmentsModifiedAt: Value(fsAttachmentsModifiedAt),
      ),
    );
  }

  Future<List<String>> listAllNoteIds() async {
    final rows = await select(notes).get();
    return rows.map((row) => row.id).toList();
  }

  Future<
      ({
        DateTime? meta,
        DateTime? md,
        DateTime? attachments,
      })?> getNoteFsSignatures(String id) async {
    final row =
        await (select(notes)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return (
      meta: row.fsMetaModifiedAt,
      md: row.fsMarkdownModifiedAt,
      attachments: row.fsAttachmentsModifiedAt,
    );
  }

  Future<void> indexNoteFts(
    String noteId,
    String title,
    String markdown, {
    Iterable<String> attachmentNames = const [],
    Iterable<String> tags = const [],
  }) async {
    if (!ftsAvailable) return;
    await customStatement(
      'DELETE FROM note_fts WHERE note_id = ?',
      [noteId],
    );
    final indexed = _ftsIndexedText(title, markdown, attachmentNames, tags);
    await customStatement(
      'INSERT INTO note_fts (note_id, body) VALUES (?, ?)',
      [noteId, indexed],
    );
  }

  static String _ftsIndexedText(
    String title,
    String markdown,
    Iterable<String> attachmentNames,
    Iterable<String> tags,
  ) {
    final parts = <String>[];
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) parts.add(trimmedTitle);
    if (markdown.isNotEmpty) parts.add(markdown);
    for (final tag in tags) {
      final trimmed = tag.trim();
      if (trimmed.isNotEmpty) parts.add(trimmed);
    }
    for (final name in attachmentNames) {
      final trimmed = name.trim();
      if (trimmed.isNotEmpty) parts.add(trimmed);
    }
    return parts.join('\n');
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
      if (row.deleted) continue;
      final attachments = await (select(noteAttachments)
            ..where((t) => t.noteId.equals(row.id)))
          .get();
      await indexNoteFts(
        row.id,
        row.title,
        row.markdown,
        attachmentNames: attachments.map((a) => a.name),
        tags: parseTagsJson(row.tags),
      );
    }
  }

  Future<List<String>> listDistinctTags() async {
    try {
      final rows = await customSelect(
        '''
        SELECT DISTINCT je.value AS tag
        FROM notes n, json_each(n.tags) je
        WHERE n.deleted = 0
        ORDER BY tag COLLATE NOCASE
        ''',
        readsFrom: {notes},
      ).get();
      return rows.map((row) => row.read<String>('tag')).toList();
    } catch (_) {
      final rows =
          await (select(notes)..where((t) => t.deleted.equals(false))).get();
      final tags = <String>{};
      for (final row in rows) {
        tags.addAll(parseTagsJson(row.tags));
      }
      final sorted = tags.toList()..sort();
      return sorted;
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
    final noteRows = await (select(notes)
          ..where(
            (t) =>
                t.deleted.equals(false) &
                (t.markdown.like(pattern) | t.title.like(pattern)),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit))
        .get();

    final attachmentRows = await (select(noteAttachments)
          ..where((t) => t.name.like(pattern)))
        .get();
    final attachmentNoteIds = attachmentRows.map((row) => row.noteId).toSet();

    final extraRows = attachmentNoteIds.isEmpty
        ? <NoteRow>[]
        : await (select(notes)
              ..where(
                (t) => t.deleted.equals(false) & t.id.isIn(attachmentNoteIds),
              ))
            .get();

    final merged = <String, NoteRow>{
      for (final row in noteRows) row.id: row,
      for (final row in extraRows) row.id: row,
    };

    final attachmentNamesByNote = <String, Set<String>>{};
    for (final row in attachmentRows) {
      attachmentNamesByNote.putIfAbsent(row.noteId, () => {}).add(row.name);
    }

    final sorted = merged.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return sorted
        .take(limit)
        .map(
          (row) => (
            noteId: row.id,
            snippet: _searchLikeSnippet(
              row: row,
              query: query,
              attachmentNames: attachmentNamesByNote[row.id] ?? const {},
            ),
          ),
        )
        .toList();
  }

  static String _searchLikeSnippet({
    required NoteRow row,
    required String query,
    required Set<String> attachmentNames,
  }) {
    final lowered = query.toLowerCase();
    for (final name in attachmentNames) {
      if (name.toLowerCase().contains(lowered)) return name;
    }
    if (row.title.trim().isNotEmpty &&
        row.title.toLowerCase().contains(lowered)) {
      return row.title.trim();
    }
    return previewSnippetFromMarkdown(row.markdown, maxLen: 48);
  }

  Future<void> replaceAttachments(
      String noteId, List<NoteAttachmentsCompanion> rows) async {
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
    String? operation,
  }) {
    return (delete(syncOutbox)
          ..where(
            (t) {
              var expr =
                  t.entityType.equals(entityType) & t.entityId.equals(entityId);
              if (operation != null) {
                expr = expr & t.operation.equals(operation);
              }
              return expr;
            },
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
    return (select(syncOutbox)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
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
