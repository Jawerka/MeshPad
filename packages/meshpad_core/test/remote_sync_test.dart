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

    final attachmentSource = File('${dirA.path}/payload.txt');
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
    expect(await repoA.pendingOutboxCount(), 0);
  });

  test('outbox stays when remote has note meta but missing attachments',
      () async {
    final dirA = await Directory.systemTemp.createTemp('remote_ack_a_');
    final dirB = await Directory.systemTemp.createTemp('remote_ack_b_');
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

    final attachmentSource = File('${dirA.path}/payload.txt');
    await attachmentSource.writeAsBytes([9, 8, 7]);
    await repoA.createNote(
      markdown: 'needs attachment ack',
      attachmentPaths: [attachmentSource.path],
    );
    expect(await repoA.pendingOutboxCount(), greaterThan(0));

    await engineA.syncWithRemote(_MetaOnlyGateway(engineB));

    expect((await repoB.listNotes()).single.attachments.length, 1);
    expect(await repoA.pendingOutboxCount(), greaterThan(0));
  });

  test('partial push failure bumps retry only for failed note', () async {
    final dirA = await Directory.systemTemp.createTemp('remote_partial_a_');
    final dirB = await Directory.systemTemp.createTemp('remote_partial_b_');
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

    final okFile = File('${dirA.path}/ok.txt');
    await okFile.writeAsBytes([1]);
    final badFile = File('${dirA.path}/bad.txt');
    await badFile.writeAsBytes([2]);

    await repoA.createNote(
      markdown: 'note ok',
      attachmentPaths: [okFile.path],
    );
    await repoA.createNote(
      markdown: 'note bad',
      attachmentPaths: [badFile.path],
    );

    final notes = await repoA.listNotes();
    final badNoteId = notes.firstWhere((n) => n.markdown == 'note bad').id;

    final result = await engineA.syncWithRemote(
      _FailPushNoteGateway(engineB, badNoteId),
    );

    expect(result.failedPushNoteIds, [badNoteId]);
    expect((await repoB.listNotes()).length, 1);

    final outbox = await repoA.listOutbox();
    final badEntry = outbox.firstWhere((e) => e.entityId == badNoteId);
    expect(badEntry.retryCount, 0);

    await OutboxProcessor().recordOutboxRetriesForNoteIds(
      repoA,
      result.failedPushNoteIds,
    );
    final bumped = await repoA.listOutbox();
    expect(
      bumped.firstWhere((e) => e.entityId == badNoteId).retryCount,
      1,
    );
    expect(
      bumped
          .where((e) => e.entityId != badNoteId)
          .every((e) => e.retryCount == 0),
      isTrue,
    );
  });

  test('attachment fetch failure does not abort note meta pull', () async {
    final dirA = await Directory.systemTemp.createTemp('remote_att_fail_a_');
    final dirB = await Directory.systemTemp.createTemp('remote_att_fail_b_');
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

    final attachmentSource = File('${dirB.path}/payload.txt');
    await attachmentSource.writeAsBytes([1, 2, 3]);
    await repoB.createNote(
      markdown: 'remote with attachment',
      attachmentPaths: [attachmentSource.path],
    );

    await engineA.syncWithRemote(_FailingAttachmentGateway(engineB));

    expect((await repoA.listNotes()).single.markdown, 'remote with attachment');
    expect((await repoA.listNotes()).single.attachments.length, 1);
    expect(
      await repoA.attachmentMatches(
        (await repoA.listNotes()).single.id,
        (await repoA.listNotes()).single.attachments.first,
      ),
      isFalse,
    );
  });

  test('attachment push failure marks note for retry', () async {
    final dirA = await Directory.systemTemp.createTemp('remote_att_push_a_');
    final dirB = await Directory.systemTemp.createTemp('remote_att_push_b_');
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

    final badFile = File('${dirA.path}/bad.txt');
    await badFile.writeAsBytes([2]);
    await repoA.createNote(
      markdown: 'note bad attachment',
      attachmentPaths: [badFile.path],
    );
    final badNoteId = (await repoA.listNotes()).single.id;

    final result = await engineA.syncWithRemote(
      _FailAttachmentOnNoteGateway(engineB, badNoteId),
    );

    expect(result.failedPushNoteIds, [badNoteId]);
    expect((await repoB.listNotes()).single.markdown, 'note bad attachment');
    expect(await repoA.pendingOutboxCount(), greaterThan(0));

    await OutboxProcessor().recordOutboxRetriesForNoteIds(
      repoA,
      result.failedPushNoteIds,
    );
    final bumped = await repoA.listOutbox();
    expect(
      bumped.firstWhere((e) => e.entityId == badNoteId).retryCount,
      1,
    );
  });
}

class _FailingAttachmentGateway implements RemoteSyncGateway {
  _FailingAttachmentGateway(this._engine);

  final SyncEngine _engine;

  @override
  Future<List<NoteHead>> fetchCatalog() => _engine.localCatalog();

  @override
  Future<RemoteNoteSnapshot?> fetchNote(String id) => _engine.exportNote(id);

  @override
  Future<NoteApplyResult> pushNote(RemoteNoteSnapshot snapshot) =>
      _engine.applyRemote(snapshot);

  @override
  Future<List<int>?> fetchAttachment(String noteId, String fileName) {
    throw StateError('attachment unavailable');
  }

  @override
  Future<void> pushAttachment(
    String noteId,
    AttachmentMeta meta,
    List<int> bytes,
  ) =>
      _engine.notes.storeRemoteAttachment(noteId, meta, bytes);
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

/// Applies note meta but never stores attachment bytes (partial sync scenario).
class _MetaOnlyGateway implements RemoteSyncGateway {
  _MetaOnlyGateway(this._engine);

  final SyncEngine _engine;

  @override
  Future<List<NoteHead>> fetchCatalog() => _engine.localCatalog();

  @override
  Future<RemoteNoteSnapshot?> fetchNote(String id) => _engine.exportNote(id);

  @override
  Future<NoteApplyResult> pushNote(RemoteNoteSnapshot snapshot) =>
      _engine.applyRemote(snapshot);

  @override
  Future<List<int>?> fetchAttachment(String noteId, String fileName) async =>
      null;

  @override
  Future<void> pushAttachment(
    String noteId,
    AttachmentMeta meta,
    List<int> bytes,
  ) async {}
}

class _FailPushNoteGateway implements RemoteSyncGateway {
  _FailPushNoteGateway(this._engine, this._failNoteId);

  final SyncEngine _engine;
  final String _failNoteId;

  @override
  Future<List<NoteHead>> fetchCatalog() => _engine.localCatalog();

  @override
  Future<RemoteNoteSnapshot?> fetchNote(String id) => _engine.exportNote(id);

  @override
  Future<NoteApplyResult> pushNote(RemoteNoteSnapshot snapshot) async {
    if (snapshot.meta.id == _failNoteId) {
      throw StateError('push failed');
    }
    return _engine.applyRemote(snapshot);
  }

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

class _FailAttachmentOnNoteGateway implements RemoteSyncGateway {
  _FailAttachmentOnNoteGateway(this._engine, this._failNoteId);

  final SyncEngine _engine;
  final String _failNoteId;

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
  ) async {
    if (noteId == _failNoteId) {
      throw StateError('attachment push failed');
    }
    await _engine.notes.storeRemoteAttachment(noteId, meta, bytes);
  }
}
