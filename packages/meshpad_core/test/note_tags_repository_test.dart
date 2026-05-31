import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  late MeshPadDatabase db;
  late NoteRepository repo;
  late String dataDir;

  setUp(() async {
    db = MeshPadDatabase.inMemory();
    dataDir = (await Directory.systemTemp.createTemp('meshpad_tags_')).path;
    repo = createNoteRepository(
      dataDir: dataDir,
      defaultAuthor: 'local',
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('setNoteTags persists and filters feed', () async {
    final note = await repo.createNote(markdown: '# hello');
    await repo.setNoteTags(note.id, ['Work', 'work', 'ideas']);

    final loaded = await repo.getNote(note.id);
    expect(loaded?.tags, ['work', 'ideas']);

    expect(await repo.listDistinctTags(), ['ideas', 'work']);

    final filtered = await repo.listNotesSlice(
      offset: 0,
      limit: 10,
      tag: 'work',
    );
    expect(filtered.map((n) => n.id), [note.id]);

    final empty = await repo.listNotesSlice(
      offset: 0,
      limit: 10,
      tag: 'missing',
    );
    expect(empty, isEmpty);
  });
}
