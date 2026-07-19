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
    tempDir = await Directory.systemTemp.createTemp('meshpad_repo_');
    db = MeshPadDatabase.inMemory();
    repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test-device',
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('create note writes FS and indexes DB', () async {
    final note = await repo.createNote(title: 'Заголовок', markdown: '# Текст');
    expect(note.title, 'Заголовок');
    expect(note.markdown, '# Текст');

    final fromFs = await repo.getNote(note.id);
    expect(fromFs?.title, 'Заголовок');

    final list = await repo.listNotes();
    expect(list.length, 1);
    expect(list.first.id, note.id);
  });

  test('update note changes updatedAt', () async {
    final note = await repo.createNote(markdown: 'old');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final updated = await repo.updateNote(note.id, markdown: 'new');
    expect(updated.markdown, 'new');
    expect(updated.updatedAt.isAfter(note.updatedAt), isTrue);
  });

  test('delete and restore via trash', () async {
    final note = await repo.createNote(title: 'x');
    await repo.deleteNote(note.id);

    expect(await repo.listNotes(), isEmpty);
    final trash = await repo.listTrash();
    expect(trash.length, 1);

    await repo.restoreNote(note.id);
    expect((await repo.listNotes()).length, 1);
    expect(await repo.listTrash(), isEmpty);
  });

  test('deleteNote removes attachment files from disk', () async {
    final file = File(p.join(tempDir.path, 'photo.bin'));
    await file.writeAsBytes([1, 2, 3, 4]);
    final note = await repo.createNote(
      markdown: 'with file',
      attachmentPaths: [file.path],
    );
    expect(note.attachments, isNotEmpty);
    final attDir = Directory(
      p.join(tempDir.path, 'notes', note.id, 'attachments'),
    );
    expect(await attDir.exists(), isTrue);
    expect(attDir.listSync(), isNotEmpty);

    await repo.deleteNote(note.id);

    final trashed = await repo.getNote(note.id);
    expect(trashed?.deleted, isTrue);
    expect(trashed?.attachments, isEmpty);
    expect(
      await attDir.exists() && attDir.listSync().isNotEmpty,
      isFalse,
    );
  });

  test('emptyTrash permanently removes all trashed notes', () async {
    await repo.createNote(title: 'a');
    final b = await repo.createNote(title: 'b');
    await repo.deleteNote(b.id);

    expect(await repo.emptyTrash(), 1);
    expect(await repo.listTrash(), isEmpty);
    expect((await repo.listNotes()).length, 1);
    expect(await repo.getNote(b.id), isNull);
    final meta = await repo.readNoteMeta(b.id);
    expect(meta?.purged, isTrue);
  });

  test('purgeExpiredTrash removes notes older than ttl', () async {
    final note = await repo.createNote(title: 'old trash');
    await repo.deleteNote(note.id);

    final metaPath = p.join(tempDir.path, 'notes', note.id, 'meta.json');
    final raw =
        jsonDecode(await File(metaPath).readAsString()) as Map<String, dynamic>;
    raw['deleted_at'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 8))
        .toIso8601String();
    await File(metaPath).writeAsString(jsonEncode(raw));
    await repo.reconcileFromFilesystem();

    final purged = await repo.purgeExpiredTrash();
    expect(purged, 1);
    expect(await repo.listTrash(), isEmpty);
    expect(await repo.getNote(note.id), isNull);
  });

  test('reconcile rebuilds index from FS', () async {
    final note = await repo.createNote(title: 'reconcile');
    final db = MeshPadDatabase.inMemory();
    final repo2 = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test-device',
      database: db,
    );
    expect(await repo2.listNotes(), isEmpty);
    final count = await repo2.reconcileFromFilesystem();
    expect(count, 1);
    expect((await repo2.listNotes()).first.title, note.title);
  });
}
