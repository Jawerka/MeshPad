import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Notes, NoteAttachments, SyncOutbox, Devices])
class MeshPadDatabase extends _$MeshPadDatabase {
  MeshPadDatabase(super.e);

  MeshPadDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

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
  }) {
    return into(notes).insertOnConflictUpdate(
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
  }

  Future<void> replaceAttachments(String noteId, List<NoteAttachmentsCompanion> rows) async {
    await (delete(noteAttachments)..where((t) => t.noteId.equals(noteId))).go();
    if (rows.isNotEmpty) {
      await batch((b) => b.insertAll(noteAttachments, rows));
    }
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
