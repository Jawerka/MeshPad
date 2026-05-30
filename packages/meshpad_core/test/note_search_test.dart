import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late MeshPadDatabase db;
  late NoteRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_search_');
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

  test('search finds note by markdown body', () async {
    await repo.createNote(markdown: 'Уникальный текст про MeshPad синхронизацию');
    await repo.createNote(markdown: 'Другая заметка без совпадений');

    final hits = await repo.searchNotes('MeshPad');
    expect(hits.length, 1);
    expect(hits.first.note.markdown, contains('MeshPad'));
    expect(hits.first.snippet, isNotEmpty);
  });

  test('search ignores deleted notes', () async {
    final note = await repo.createNote(markdown: 'секретное слово alpha');
    await repo.deleteNote(note.id);

    final hits = await repo.searchNotes('alpha');
    expect(hits, isEmpty);
  });
}
