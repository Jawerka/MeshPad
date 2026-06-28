import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late MeshPadDatabase db;
  late NoteRepository repo;
  late NoteOperationJournal journal;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_ops_');
    db = createMeshPadDatabase(tempDir.path);
    journal = NoteOperationJournal(paths: MeshPadPaths(tempDir.path));
    repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'device-a',
      database: db,
      operationJournal: journal,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('create and delete append operation files', () async {
    final note = await repo.createNote(title: 'Hi', markdown: 'body');
    await repo.deleteNote(note.id);

    final files = await journal.listOperationFiles();
    expect(files.length, 2);

    final types = <String>[];
    for (final file in files) {
      final line = await file.readAsLines();
      expect(line, hasLength(1));
      final json = jsonDecode(line.first) as Map<String, dynamic>;
      types.add(json['type'] as String);
      expect(json['note_id'], note.id);
      expect(json['device'], 'device-a');
    }
    expect(types, containsAll(['create_note', 'delete_note']));
  });

  test('purge writes purge_note operation', () async {
    final note = await repo.createNote(title: 'Old', markdown: 'x');
    await repo.deleteNote(note.id);

    final metaPath =
        '${tempDir.path}/notes/${note.id}/meta.json';
    final raw =
        jsonDecode(await File(metaPath).readAsString()) as Map<String, dynamic>;
    raw['deleted_at'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 8))
        .toIso8601String();
    await File(metaPath).writeAsString(jsonEncode(raw));
    await repo.reconcileFromFilesystem();
    expect(await repo.purgeExpiredTrash(), 1);

    final files = await journal.listOperationFiles();
    expect(files.length, greaterThanOrEqualTo(2));
    final types = <String>[];
    for (final file in files) {
      final line = await file.readAsLines();
      expect(line, hasLength(1));
      final json = jsonDecode(line.first) as Map<String, dynamic>;
      types.add(json['type'] as String);
      expect(json['note_id'], note.id);
    }
    expect(types, containsAll(['create_note', 'delete_note', 'purge_note']));
  });
}
