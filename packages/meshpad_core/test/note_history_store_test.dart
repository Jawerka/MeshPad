import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late MeshPadDatabase db;
  late NoteRepository repo;
  late NoteHistoryStore history;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_hist_');
    db = createMeshPadDatabase(tempDir.path);
    history = NoteHistoryStore(
        paths: MeshPadPaths(tempDir.path), snapshotInterval: 3);
    repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'device-a',
      database: db,
      historyStore: history,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('snapshot written every N revisions', () async {
    final note = await repo.createNote(title: 'v0', markdown: 'body 0');
    for (var i = 1; i <= 3; i++) {
      await repo.updateNote(note.id, markdown: 'body $i');
    }

    expect(await repo.listNoteHistoryRevisions(note.id), [3]);

    final folder = await repo.readNoteHistoryRevision(note.id, 3);
    expect(folder?.markdown, 'body 3');
    expect(folder?.meta.revision, 3);

    final revDir = history.revisionDir(note.id, 3);
    expect(await File(p.join(revDir, 'meta.json')).exists(), isTrue);
    expect(await File(p.join(revDir, 'note.md')).exists(), isTrue);
  });

  test('maybeSnapshot is idempotent for same revision', () async {
    final note = await repo.createNote(markdown: 'x');
    for (var i = 0; i < 3; i++) {
      await repo.updateNote(note.id, markdown: 'line $i');
    }
    final current = (await repo.getNote(note.id))!;
    expect(await history.maybeSnapshot(current), isFalse);
    expect(await repo.listNoteHistoryRevisions(note.id), [3]);
  });

  test('restoreNoteHistoryRevision applies markdown from snapshot', () async {
    final note = await repo.createNote(markdown: 'start');
    for (var i = 1; i <= 3; i++) {
      await repo.updateNote(note.id, markdown: 'rev $i');
    }
    await repo.updateNote(note.id, markdown: 'latest');

    await repo.restoreNoteHistoryRevision(note.id, 3);
    expect((await repo.getNote(note.id))?.markdown, 'rev 3');
    expect((await repo.getNote(note.id))?.revision, 5);

    await repo.updateNote(note.id, markdown: 'after restore');
    expect(await repo.listNoteHistoryRevisions(note.id), [3, 6]);
  });
}
