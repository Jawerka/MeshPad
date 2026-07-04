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
    await repo.createNote(
        markdown: 'Уникальный текст про MeshPad синхронизацию');
    await repo.createNote(markdown: 'Другая заметка без совпадений');

    final hits = await repo.searchNotes('MeshPad');
    expect(hits.length, 1);
    expect(hits.first.note.markdown, contains('MeshPad'));
    expect(hits.first.snippet, isNotEmpty);
  });

  test('search finds note by title', () async {
    await repo.createNote(title: 'Список покупок', markdown: 'молоко');
    await repo.createNote(title: 'Другое', markdown: 'текст');

    final hits = await repo.searchNotes('покупок');
    expect(hits.length, 1);
    expect(hits.first.note.title, 'Список покупок');
  });

  test('search finds note by attachment name', () async {
    final note = await repo.createNote(markdown: 'фото');
    await repo.addAttachmentFromBytes(
      note.id,
      fileName: 'vacation-beach.jpg',
      bytes: [1, 2, 3],
    );

    final hits = await repo.searchNotes('vacation-beach');
    expect(hits.length, 1);
    expect(hits.first.note.id, note.id);
  });

  test('createNote derives title from markdown heading', () async {
    final note = await repo.createNote(markdown: '# Встреча\n\nПовестка');
    expect(note.title, 'Встреча');
  });

  test('search ignores deleted notes', () async {
    final note = await repo.createNote(markdown: 'секретное слово alpha');
    await repo.deleteNote(note.id);

    final hits = await repo.searchNotes('alpha');
    expect(hits, isEmpty);
  });
}
