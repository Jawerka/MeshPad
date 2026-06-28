import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';
import 'package:test/test.dart';

void main() {
  late Libp2pSidecarServer sidecar;
  late HttpServer httpServer;
  late int port;

  setUp(() async {
    sidecar = Libp2pSidecarServer(enableDiscovery: false);
    httpServer = await serveLibp2pSidecar(server: sidecar, port: 0);
    port = httpServer.port;
  });

  tearDown(() async {
    await httpServer.close(force: true);
    await sidecar.close();
  });

  test('requestSync uses wire data plane and skips unreachable LAN peer', () async {
    final wire = Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:$port');
    await wire.pushSnapshot(
      snapshot: {
        'meta': {
          'schema_version': 2,
          'id': 'note-wire',
          'title': 'Wire',
          'author': 'peer',
          'created_at': '2026-06-01T00:00:00.000Z',
          'updated_at': '2026-06-01T00:00:00.000Z',
          'deleted': false,
        },
        'markdown': 'wire',
      },
    );

    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);
    final repo = createNoteRepository(
      dataDir: (await Directory.systemTemp.createTemp('wire_sync_')).path,
      defaultAuthor: 'local',
      database: db,
    );
    final identity = LocalDeviceIdentity(
      peerId: 'local',
      displayName: 'Local',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final engine = SyncEngine(notes: repo, identity: identity);

    final native = HttpLibp2pNativeApi(baseUrl: 'http://127.0.0.1:$port');
    final transport = Libp2pSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      nativeApi: native,
      trySidecar: false,
    );

    await transport.start(startLanStack: false);

    await transport.requestSync(peerId: 'remote-peer');

    final note = await repo.getNote('note-wire');
    expect(note?.markdown, 'wire');

    await transport.stop();
    transport.dispose();
  });
}
