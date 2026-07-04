import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late MeshPadDatabase db;
  late NoteRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_conflict_');
    db = MeshPadDatabase.inMemory();
    repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'device-a',
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
      'A edits title, B edits body at same time → conflict copy, no silent loss',
      () async {
    final note = await repo.createNote(title: 'Original', markdown: 'shared');
    final at = DateTime.utc(2026, 5, 31, 12);
    final noteDir = p.join(tempDir.path, 'notes', note.id);
    final localMeta = note.toMeta().copyWith(
          title: 'Title from A',
          updatedAt: at,
        );
    await File(p.join(noteDir, 'meta.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert(localMeta.toJson()),
    );
    await File(p.join(noteDir, 'note.md')).writeAsString('Body from A');
    await repo.reconcileFromFilesystem();

    final remoteMeta = NoteMeta(
      schemaVersion: note.toMeta().schemaVersion,
      id: note.id,
      title: 'Title from B',
      createdAt: note.createdAt,
      updatedAt: at,
      author: 'device-b',
    );

    final result = await repo.applyRemoteMerge(
      remoteMeta,
      'Body from B',
    );

    expect(result, NoteApplyResult.conflictCopyCreated);

    final kept = await repo.getNote(note.id);
    expect(kept?.title, 'Title from A');
    expect(kept?.markdown, contains('Body from A'));

    final copies = await repo.listConflictCopies(note.id);
    expect(copies, isNotEmpty);

    final remote = await repo.readConflictCopy(note.id, copies.first.fileName);
    expect(remote?.title, 'Title from B');
    expect(remote?.markdown, 'Body from B');
  });

  test('local save increments revision', () async {
    final note = await repo.createNote(markdown: 'v1');
    expect(note.revision, 0);

    final updated = await repo.updateNote(note.id, markdown: 'v2');
    final folder = await File(
      p.join(tempDir.path, 'notes', note.id, 'meta.json'),
    ).readAsString();
    final meta = NoteMeta.fromJson(
      jsonDecode(folder) as Map<String, dynamic>,
    );
    expect(meta.revision, greaterThanOrEqualTo(1));
    expect(updated.revision, greaterThanOrEqualTo(1));
  });
}
