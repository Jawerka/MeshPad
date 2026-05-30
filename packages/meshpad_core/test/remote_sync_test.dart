import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('syncWithRemote pulls and pushes notes', () async {
    final dirA = await Directory.systemTemp.createTemp('remote_a_');
    final dirB = await Directory.systemTemp.createTemp('remote_b_');
    final dbA = MeshPadDatabase.inMemory();
    final dbB = MeshPadDatabase.inMemory();

    addTearDown(() async {
      await dbA.close();
      await dbB.close();
      if (await dirA.exists()) await dirA.delete(recursive: true);
      if (await dirB.exists()) await dirB.delete(recursive: true);
    });

    final repoA = createNoteRepository(
      dataDir: dirA.path,
      defaultAuthor: 'a',
      database: dbA,
    );
    final repoB = createNoteRepository(
      dataDir: dirB.path,
      defaultAuthor: 'b',
      database: dbB,
    );

    final engineA = SyncEngine(
      notes: repoA,
      identity: LocalDeviceIdentity(
        peerId: 'a',
        displayName: 'A',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final engineB = SyncEngine(
      notes: repoB,
      identity: LocalDeviceIdentity(
        peerId: 'b',
        displayName: 'B',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await repoA.createNote(markdown: 'only on A');

    final gatewayB = _MemoryGateway(engineB);
    final result = await engineA.syncWithRemote(gatewayB);

    expect(result.pulled, 0);
    expect(result.receivedByPeer, 1);
    expect((await repoB.listNotes()).single.markdown, 'only on A');
  });

  test('syncWithRemote transfers attachments', () async {
    final dirA = await Directory.systemTemp.createTemp('remote_att_a_');
    final dirB = await Directory.systemTemp.createTemp('remote_att_b_');
    final dbA = MeshPadDatabase.inMemory();
    final dbB = MeshPadDatabase.inMemory();

    addTearDown(() async {
      await dbA.close();
      await dbB.close();
      if (await dirA.exists()) await dirA.delete(recursive: true);
      if (await dirB.exists()) await dirB.delete(recursive: true);
    });

    final repoA = createNoteRepository(
      dataDir: dirA.path,
      defaultAuthor: 'a',
      database: dbA,
    );
    final repoB = createNoteRepository(
      dataDir: dirB.path,
      defaultAuthor: 'b',
      database: dbB,
    );

    final engineA = SyncEngine(
      notes: repoA,
      identity: LocalDeviceIdentity(
        peerId: 'a',
        displayName: 'A',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final engineB = SyncEngine(
      notes: repoB,
      identity: LocalDeviceIdentity(
        peerId: 'b',
        displayName: 'B',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final attachmentSource = File('${dirA.path}/payload.bin');
    await attachmentSource.writeAsBytes([1, 2, 3, 4, 5]);
    await repoA.createNote(
      markdown: 'with attachment',
      attachmentPaths: [attachmentSource.path],
    );

    await engineA.syncWithRemote(_MemoryGateway(engineB));

    final noteB = (await repoB.listNotes()).single;
    expect(noteB.attachments.length, 1);
    expect(
      await repoB.attachmentMatches(noteB.id, noteB.attachments.first),
      isTrue,
    );
  });
}

class _MemoryGateway implements RemoteSyncGateway {
  _MemoryGateway(this._engine);

  final SyncEngine _engine;

  @override
  Future<List<NoteHead>> fetchCatalog() => _engine.localCatalog();

  @override
  Future<RemoteNoteSnapshot?> fetchNote(String id) => _engine.exportNote(id);

  @override
  Future<NoteApplyResult> pushNote(RemoteNoteSnapshot snapshot) =>
      _engine.applyRemote(snapshot);

  @override
  Future<List<int>?> fetchAttachment(String noteId, String fileName) =>
      _engine.notes.readAttachmentBytes(noteId, fileName);

  @override
  Future<void> pushAttachment(
    String noteId,
    AttachmentMeta meta,
    List<int> bytes,
  ) =>
      _engine.notes.storeRemoteAttachment(noteId, meta, bytes);
}
