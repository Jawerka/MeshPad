import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('runForegroundSyncInIsolate syncs notes with resolved endpoint',
      () async {
    final dirA = await Directory.systemTemp.createTemp('fg_sync_a_');
    final dirB = await Directory.systemTemp.createTemp('fg_sync_b_');
    addTearDown(() async {
      if (await dirA.exists()) await dirA.delete(recursive: true);
      if (await dirB.exists()) await dirB.delete(recursive: true);
    });

    final dbB = MeshPadDatabase.inMemory();
    addTearDown(dbB.close);

    final storeA = DeviceIdentityStore(paths: MeshPadPaths(dirA.path));
    final storeB = DeviceIdentityStore(paths: MeshPadPaths(dirB.path));
    final sharedToken = generateSyncAuthToken();
    final identityA =
        await storeA.loadOrCreateIdentity(defaultDisplayName: 'A');

    await storeA.trustDevice(
      peerId: 'peer-b',
      name: 'B',
      authToken: sharedToken,
    );
    await storeB.trustDevice(
      peerId: identityA.peerId,
      name: identityA.displayName,
      authToken: sharedToken,
    );

    final repoB = createNoteRepository(
      dataDir: dirB.path,
      defaultAuthor: 'b',
      database: dbB,
    );
    final engineB = SyncEngine(
      notes: repoB,
      identity: LocalDeviceIdentity(
        peerId: 'peer-b',
        displayName: 'B',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final serverB = LanPeerServer(
      preferredPort: 0,
      getEngine: () async => engineB,
      lookupTrustedPeer: storeB.trustedRecordFor,
    );
    final portB = await serverB.start();
    addTearDown(serverB.stop);

    await repoB.createNote(markdown: 'from B');

    final endpoint = LanPeerEndpoint(
      peerId: 'peer-b',
      displayName: 'B',
      host: '127.0.0.1',
      httpPort: portB,
    );

    var progressEvents = 0;
    final result = await runForegroundSyncInIsolate(
      dataDir: dirA.path,
      defaultAuthor: identityA.displayName,
      networkProfile: LanNetworkProfile.normal,
      localPeerId: identityA.peerId,
      resolvedEndpoints: [endpoint],
      authTokens: {'peer-b': sharedToken},
      onProgress: (_) => progressEvents++,
    );

    expect(result.status, LanSyncRunStatus.completed);
    expect(result.noteCount, greaterThan(0));
    expect(progressEvents, greaterThan(0));

    final dbA = createMeshPadDatabase(dirA.path);
    addTearDown(dbA.close);
    final repoA = createNoteRepository(
      dataDir: dirA.path,
      defaultAuthor: identityA.displayName,
      database: dbA,
    );
    final notes = await repoA.listNotesSlice(offset: 0, limit: 10);
    expect(notes.any((note) => note.markdown.contains('from B')), isTrue);
  });
}
