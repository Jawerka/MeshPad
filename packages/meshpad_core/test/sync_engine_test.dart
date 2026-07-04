import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

NoteRepository _repo(String dir, MeshPadDatabase db) => createNoteRepository(
      dataDir: dir,
      defaultAuthor: 'peer',
      database: db,
    );

SyncEngine _engine(NoteRepository repo, String peerId) => SyncEngine(
      notes: repo,
      identity: LocalDeviceIdentity(
        peerId: peerId,
        displayName: peerId,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

void main() {
  late Directory dirA;
  late Directory dirB;
  late MeshPadDatabase dbA;
  late MeshPadDatabase dbB;
  late NoteRepository repoA;
  late NoteRepository repoB;
  late SyncEngine engineA;
  late SyncEngine engineB;

  setUp(() async {
    dirA = await Directory.systemTemp.createTemp('meshpad_sync_a_');
    dirB = await Directory.systemTemp.createTemp('meshpad_sync_b_');
    dbA = MeshPadDatabase.inMemory();
    dbB = MeshPadDatabase.inMemory();
    repoA = _repo(dirA.path, dbA);
    repoB = _repo(dirB.path, dbB);
    engineA = _engine(repoA, 'device-a');
    engineB = _engine(repoB, 'device-b');
  });

  tearDown(() async {
    await dbA.close();
    await dbB.close();
    if (await dirA.exists()) await dirA.delete(recursive: true);
    if (await dirB.exists()) await dirB.delete(recursive: true);
  });

  test('sync propagates new note to peer', () async {
    await repoA.createNote(markdown: 'from A');

    final result = await syncEngines(engineA, engineB);

    expect(result.pulled, 0);
    expect(result.receivedByPeer, 1);
    expect((await repoB.listNotes()).length, 1);
    expect((await repoB.listNotes()).first.markdown, 'from A');
  });

  test('LWW keeps newer note on conflict', () async {
    final note = await repoA.createNote(markdown: 'A version');
    await repoB.applyRemoteMerge(
      note.toMeta().copyWith(updatedAt: DateTime.utc(2026, 1, 1)),
      'B stale',
    );

    await repoA.updateNote(note.id, markdown: 'A newer');
    await syncEngines(engineA, engineB);

    expect((await repoB.getNote(note.id))?.markdown, 'A newer');
  });

  test('tombstone sync hides note on peer', () async {
    final note = await repoA.createNote(markdown: 'delete me');
    await syncEngines(engineA, engineB);
    expect((await repoB.listNotes()).length, 1);

    await repoA.deleteNote(note.id);
    await syncEngines(engineA, engineB);

    expect(await repoB.listNotes(), isEmpty);
    expect((await repoB.listTrash()).length, 1);
  });

  test('outbox clears after successful sync', () async {
    await repoA.createNote(markdown: 'queued');
    expect(await repoA.pendingOutboxCount(), greaterThan(0));

    await syncEngines(engineA, engineB);

    expect(await repoA.pendingOutboxCount(), 0);
  });

  test('remote merge does not enqueue outbox', () async {
    final note = await repoA.createNote(markdown: 'from A');
    await syncEngines(engineA, engineB);

    expect(await repoB.pendingOutboxCount(), 0);
    expect((await repoB.getNote(note.id))?.markdown, 'from A');
  });
}
