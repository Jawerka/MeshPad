import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

/// End-to-end: local note → outbox → coordinator → remote peer has note.
void main() {
  test('createNote outbox sync reaches trusted peer', () async {
    final dirLocal = await Directory.systemTemp.createTemp('pipe_local_');
    final dirRemote = await Directory.systemTemp.createTemp('pipe_remote_');
    final dbLocal = MeshPadDatabase.inMemory();
    final dbRemote = MeshPadDatabase.inMemory();

    addTearDown(() async {
      await dbLocal.close();
      await dbRemote.close();
      if (await dirLocal.exists()) await dirLocal.delete(recursive: true);
      if (await dirRemote.exists()) await dirRemote.delete(recursive: true);
    });

    final storeLocal = DeviceIdentityStore(paths: MeshPadPaths(dirLocal.path));
    final storeRemote =
        DeviceIdentityStore(paths: MeshPadPaths(dirRemote.path));
    final token = generateSyncAuthToken();

    final identityLocal = await storeLocal.loadOrCreateIdentity();
    const remotePeerId = 'peer-remote';

    await storeLocal.trustDevice(
      peerId: remotePeerId,
      name: 'Remote',
      authToken: token,
    );
    await storeRemote.trustDevice(
      peerId: identityLocal.peerId,
      name: identityLocal.displayName,
      authToken: token,
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

    final engineLocal = SyncEngine(notes: repoLocal, identity: identityLocal);
    final engineRemote = SyncEngine(
      notes: repoRemote,
      identity: LocalDeviceIdentity(
        peerId: remotePeerId,
        displayName: 'Remote',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final server = LanPeerServer(
      preferredPort: 0,
      getEngine: () async => engineRemote,
      lookupTrustedPeer: storeRemote.trustedRecordFor,
    );
    final port = await server.start();
    addTearDown(server.stop);

    await repoLocal.createNote(markdown: 'pipeline e2e note');
    expect(await repoLocal.pendingOutboxCount(), greaterThan(0));

    final transport = LanSyncTransport(
      getEngine: () async => engineLocal,
      getIdentity: () async => identityLocal,
      getDeviceStore: () async => storeLocal,
    );
    transport.rememberEndpoint(
      LanPeerEndpoint(
        peerId: remotePeerId,
        displayName: 'Remote',
        host: InternetAddress.loopbackIPv4.address,
        httpPort: port,
      ),
    );

    final coordinator = LanSyncCoordinator(deviceStore: storeLocal);
    final result = await coordinator.syncTrustedPeers(
      transport: transport,
      repository: repoLocal,
    );

    expect(result.status, LanSyncRunStatus.completed);
    expect((await repoRemote.listNotes()).single.markdown, 'pipeline e2e note');
    expect(await repoLocal.pendingOutboxCount(), 0);
    transport.dispose();
  });
}
