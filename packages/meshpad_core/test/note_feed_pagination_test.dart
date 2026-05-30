import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late MeshPadDatabase db;
  late NoteRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_feed_page_');
    db = createMeshPadDatabase(tempDir.path);
    repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test',
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('listNotesSlice returns bounded window', () async {
    for (var i = 0; i < 5; i++) {
      await repo.createNote(title: 'n$i', markdown: 'body $i');
    }

    final total = await repo.countActiveNotes();
    expect(total, 5);

    final tail = await repo.listNotesSlice(offset: 2, limit: 10);
    expect(tail.length, 3);
  });

  test('feed window uses last page when many notes exist', () async {
    for (var i = 0; i < 45; i++) {
      await repo.createNote(title: 'n$i', markdown: 'body $i');
    }

    const pageSize = 40;
    final total = await repo.countActiveNotes();
    final offset = total - pageSize;
    final page = await repo.listNotesSlice(offset: offset, limit: pageSize);

    expect(page.length, pageSize);
    expect(offset, 5);
  });
}
