import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lan_coord_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('syncTrustedPeers returns noPeers when trust list empty', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);

    final repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test',
      database: db,
    );
    final engine = SyncEngine(
      notes: repo,
      identity: LocalDeviceIdentity(
        peerId: 'local',
        displayName: 'Local',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final transport = LanSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => store.loadOrCreateIdentity(),
    );

    final coordinator = LanSyncCoordinator(deviceStore: store);
    final result = await coordinator.syncTrustedPeers(
      transport: transport,
      repository: repo,
    );

    expect(result.status, LanSyncRunStatus.noPeers);
    transport.dispose();
  });

  test('syncTrustedPeers does not bump outbox on transport failure', () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(peerId: 'peer-remote', name: 'Remote');
    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);

    final repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test',
      database: db,
    );
    await repo.createNote(markdown: 'pending sync');

    final identity = await store.loadOrCreateIdentity();
    final engine = SyncEngine(notes: repo, identity: identity);
    final transport = LanSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      getDeviceStore: () async => store,
    );
    await transport.start();

    final coordinator = LanSyncCoordinator(deviceStore: store);
    final result = await coordinator.syncTrustedPeers(
      transport: transport,
      repository: repo,
    );

    expect(result.status, LanSyncRunStatus.completed);
    expect(result.skippedPeerIds, contains('peer-remote'));
    final outbox = await repo.listOutbox();
    expect(outbox, isNotEmpty);
    expect(outbox.every((entry) => entry.retryCount == 0), isTrue);
    transport.dispose();
  });

  test('syncTrustedPeers continues when one peer is unreachable', () async {
    final dirLocal = await Directory.systemTemp.createTemp('lan_coord_local_');
    final dirRemote =
        await Directory.systemTemp.createTemp('lan_coord_remote_');
    addTearDown(() async {
      if (await dirLocal.exists()) await dirLocal.delete(recursive: true);
      if (await dirRemote.exists()) await dirRemote.delete(recursive: true);
    });

    final store = DeviceIdentityStore(paths: MeshPadPaths(dirLocal.path));
    final dbLocal = MeshPadDatabase.inMemory();
    final dbRemote = MeshPadDatabase.inMemory();
    addTearDown(() async {
      await dbLocal.close();
      await dbRemote.close();
    });

    final sharedToken = generateSyncAuthToken();
    await store.trustDevice(
      peerId: 'peer-good',
      name: 'Good',
      authToken: sharedToken,
    );
    await store.trustDevice(
      peerId: 'peer-missing',
      name: 'Missing',
      lanHost: '127.0.0.1',
      lanHttpPort: 1,
    );

    final repoLocal = createNoteRepository(
      dataDir: dirLocal.path,
      defaultAuthor: 'local',
      database: dbLocal,
    );
    final repoRemote = createNoteRepository(
      dataDir: dirRemote.path,
      defaultAuthor: 'remote',
      database: dbRemote,
    );

    final identity = await store.loadOrCreateIdentity();
    final engineLocal = SyncEngine(notes: repoLocal, identity: identity);
    final engineRemote = SyncEngine(
      notes: repoRemote,
      identity: LocalDeviceIdentity(
        peerId: 'peer-good',
        displayName: 'Good',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final storeRemote =
        DeviceIdentityStore(paths: MeshPadPaths(dirRemote.path));
    await storeRemote.trustDevice(
      peerId: identity.peerId,
      name: 'Local',
      authToken: sharedToken,
    );

    final server = LanPeerServer(
      preferredPort: 0,
      getEngine: () async => engineRemote,
      lookupTrustedPeer: storeRemote.trustedRecordFor,
    );
    final port = await server.start();
    addTearDown(server.stop);

    await repoLocal.createNote(markdown: 'sync me');

    final transport = LanSyncTransport(
      getEngine: () async => engineLocal,
      getIdentity: () async => identity,
      getDeviceStore: () async => store,
    );
    transport.rememberEndpoint(
      LanPeerEndpoint(
        peerId: 'peer-good',
        displayName: 'Good',
        host: InternetAddress.loopbackIPv4.address,
        httpPort: port,
      ),
    );

    final coordinator = LanSyncCoordinator(deviceStore: store);
    final result = await coordinator.syncTrustedPeers(
      transport: transport,
      repository: repoLocal,
    );

    expect(result.status, LanSyncRunStatus.completed);
    expect(result.succeededPeerIds, contains('peer-good'));
    expect(result.skippedPeerIds, contains('peer-missing'));
    expect(result.failedPeerIds, isEmpty);
    expect((await repoRemote.listNotes()).length, 1);
    transport.dispose();
  });

  test('syncTrustedPeers returns completed when all peers are unreachable',
      () async {
    final store = DeviceIdentityStore(paths: MeshPadPaths(tempDir.path));
    await store.trustDevice(
      peerId: 'peer-missing-a',
      name: 'Missing A',
      lanHost: '127.0.0.1',
      lanHttpPort: 1,
    );
    await store.trustDevice(
      peerId: 'peer-missing-b',
      name: 'Missing B',
      lanHost: '127.0.0.1',
      lanHttpPort: 2,
    );

    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);
    final repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test',
      database: db,
    );
    final identity = await store.loadOrCreateIdentity();
    final engine = SyncEngine(notes: repo, identity: identity);
    final transport = LanSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      getDeviceStore: () async => store,
    );

    final coordinator = LanSyncCoordinator(deviceStore: store);
    final result = await coordinator.syncTrustedPeers(
      transport: transport,
      repository: repo,
    );

    expect(result.status, LanSyncRunStatus.completed);
    expect(result.skippedPeerIds,
        containsAll(['peer-missing-a', 'peer-missing-b']));
    expect(result.failedPeerIds, isEmpty);
    transport.dispose();
  });
}
