import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';
import 'package:test/test.dart';

void main() {
  test('remoteWireBaseFor exposes only explicit registry entries', () async {
    final registry = Libp2pPeerWireRegistry();
    registry.rememberInferred('peer-c', 'http://192.168.1.5:45839/');
    registry.remember('peer-d', 'http://127.0.0.1:45840/');

    final sidecar = Libp2pSidecarServer(enableDiscovery: false);
    final server = await serveLibp2pSidecar(server: sidecar, port: 0);
    addTearDown(() async {
      await server.close(force: true);
      await sidecar.close();
    });

    final transport = Libp2pSyncTransport(
      getEngine: () async => SyncEngine(
        notes: createNoteRepository(
          dataDir: '.',
          defaultAuthor: 'x',
          database: MeshPadDatabase.inMemory(),
        ),
        identity: LocalDeviceIdentity(
          peerId: 'local',
          displayName: 'L',
          createdAt: DateTime.utc(2026),
        ),
      ),
      getIdentity: () async => LocalDeviceIdentity(
        peerId: 'local',
        displayName: 'L',
        createdAt: DateTime.utc(2026),
      ),
      nativeApi: HttpLibp2pNativeApi(baseUrl: 'http://127.0.0.1:${server.port}'),
      trySidecar: false,
      peerWireRegistry: registry,
    );

    await transport.start(startLanStack: false);
    expect(transport.remoteWireBaseFor('peer-c'), isNull);
    expect(transport.remoteWireBaseFor('peer-d'), 'http://127.0.0.1:45840/');
    expect(transport.peerWireBaseFor('peer-c'), isNotNull);
    await transport.stop();
    transport.dispose();
  });
}
