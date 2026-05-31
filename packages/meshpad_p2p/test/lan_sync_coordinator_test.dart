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

    expect(result.status, LanSyncRunStatus.failed);
    final outbox = await repo.listOutbox();
    expect(outbox, isNotEmpty);
    expect(outbox.every((entry) => entry.retryCount == 0), isTrue);
    transport.dispose();
  });
}
