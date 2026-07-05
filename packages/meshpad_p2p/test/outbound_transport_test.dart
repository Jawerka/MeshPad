import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('outboundOnly transport starts without binding a port', () async {
    final dir = await Directory.systemTemp.createTemp('outbound_transport_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);

    final store = DeviceIdentityStore(paths: MeshPadPaths(dir.path));
    final identity = await store.loadOrCreateIdentity(defaultDisplayName: 'A');
    final repo = createNoteRepository(
      dataDir: dir.path,
      defaultAuthor: 'A',
      database: db,
    );
    final engine = SyncEngine(notes: repo, identity: identity);

    final transport = LanSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      getDeviceStore: () async => store,
      outboundOnly: true,
      enableTls: false,
    );

    await transport.start();
    expect(transport.localHttpPort, isNull);

    await transport.stop();
  });

  test('syncTrustedPeers skips transport.start when manageTransport is false',
      () async {
    final dir = await Directory.systemTemp.createTemp('manage_transport_');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);

    final store = DeviceIdentityStore(paths: MeshPadPaths(dir.path));
    final identity = await store.loadOrCreateIdentity(defaultDisplayName: 'A');
    final repo = createNoteRepository(
      dataDir: dir.path,
      defaultAuthor: 'A',
      database: db,
    );
    final engine = SyncEngine(notes: repo, identity: identity);

    final transport = LanSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      getDeviceStore: () async => store,
      outboundOnly: true,
      enableTls: false,
    );

    final coordinator = LanSyncCoordinator(deviceStore: store);
    final result = await coordinator.syncTrustedPeers(
      transport: transport,
      repository: repo,
      trusted: const [],
      manageTransport: false,
    );

    expect(result.status, LanSyncRunStatus.noPeers);
    expect(transport.localHttpPort, isNull);
  });
}
