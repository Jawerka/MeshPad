import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';
import 'package:test/test.dart';

/// PLAN 8.2–8.3: peer B sidecar holds notes; A imports via [remote_wire_base] + wire sync.
void main() {
  test('Libp2pSyncTransport pulls note from remote sidecar wire store', () async {
    final sidecarA = Libp2pSidecarServer(enableDiscovery: false);
    final sidecarB = Libp2pSidecarServer(enableDiscovery: false);
    final serverA = await serveLibp2pSidecar(server: sidecarA, port: 0);
    final serverB = await serveLibp2pSidecar(server: sidecarB, port: 0);
    addTearDown(() async {
      await serverA.close(force: true);
      await serverB.close(force: true);
      await sidecarA.close();
      await sidecarB.close();
    });

    final wireB = Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${serverB.port}');
    await wireB.pushSnapshot(
      snapshot: {
        'meta': {
          'schema_version': 2,
          'id': 'from-b',
          'title': 'Peer B',
          'author': 'peer-b',
          'created_at': '2026-06-01T08:00:00.000Z',
          'updated_at': '2026-06-01T10:00:00.000Z',
          'deleted': false,
        },
        'markdown': '# from peer B',
      },
    );

    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);
    final repo = createNoteRepository(
      dataDir: (await Directory.systemTemp.createTemp('two_sc_')).path,
      defaultAuthor: 'peer-a',
      database: db,
    );
    final identity = LocalDeviceIdentity(
      peerId: 'peer-a',
      displayName: 'A',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final engine = SyncEngine(notes: repo, identity: identity);

    final transport = Libp2pSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      nativeApi: HttpLibp2pNativeApi(baseUrl: 'http://127.0.0.1:${serverA.port}'),
      trySidecar: false,
    );

    await transport.start(startLanStack: false);
    transport.rememberPeerWireBase(
      'peer-b',
      'http://127.0.0.1:${serverB.port}',
    );

    await transport.requestSync(peerId: 'peer-b');

    final note = await repo.getNote('from-b');
    expect(note?.markdown, '# from peer B');

    await transport.stop();
    transport.dispose();
  });
}
