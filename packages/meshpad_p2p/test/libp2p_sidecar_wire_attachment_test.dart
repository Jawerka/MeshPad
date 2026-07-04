import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';
import 'package:test/test.dart';

void main() {
  test('wire attachment push and pull round-trip', () async {
    final sidecar = Libp2pSidecarServer(enableDiscovery: false);
    final server = await serveLibp2pSidecar(server: sidecar, port: 0);
    addTearDown(() async {
      await server.close(force: true);
      await sidecar.close();
    });

    final wire =
        Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final bytes = [10, 20, 30, 40];
    expect(
      await wire.pushAttachment(noteId: 'n1', name: 'file.bin', bytes: bytes),
      isTrue,
    );
    final pulled = await wire.pullAttachment(noteId: 'n1', name: 'file.bin');
    expect(pulled, bytes);
    expect(await wire.pullAttachment(noteId: 'n1', name: 'missing'), isNull);
  });

  test('SidecarWireRemoteSyncGateway transfers attachment bytes', () async {
    final sidecar = Libp2pSidecarServer(enableDiscovery: false);
    final server = await serveLibp2pSidecar(server: sidecar, port: 0);
    addTearDown(() async {
      await server.close(force: true);
      await sidecar.close();
    });

    final wire =
        Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final gateway = SidecarWireRemoteSyncGateway(client: wire);
    const payload = [1, 2, 3, 4, 5];
    await gateway.pushAttachment(
      'note-a',
      AttachmentMeta(name: 'pic.png', size: payload.length, mime: 'image/png'),
      payload,
    );
    final fetched = await gateway.fetchAttachment('note-a', 'pic.png');
    expect(fetched, payload);
  });
}
