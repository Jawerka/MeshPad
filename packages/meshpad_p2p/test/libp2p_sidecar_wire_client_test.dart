import 'dart:io';

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

  test('fetchCatalog returns empty list from dart sidecar', () async {
    final wire = Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:$port');
    final catalog = await wire.fetchCatalog();
    expect(catalog, isEmpty);
  });

  test('wire push catalog pull round-trip via sidecar store', () async {
    final wire = Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:$port');

    final push = await wire.pushSnapshot(
      peerId: 'peer-a',
      snapshot: {
        'meta': {
          'id': 'note-1',
          'updated_at': '2026-06-01T00:00:00.000Z',
          'deleted': false,
        },
        'markdown': '# hi',
      },
    );
    expect(push.status, 'accepted');
    expect(push.lanFallback, isFalse);

    final catalog = await wire.fetchCatalog();
    expect(catalog, hasLength(1));
    expect(catalog.first.id, 'note-1');

    final pull = await wire.pullNotes(
      peerId: 'peer-a',
      noteIds: ['note-1'],
    );
    expect(pull.status, 'ok');
    expect(pull.lanFallback, isFalse);
    expect(pull.snapshots, hasLength(1));
    expect(pull.snapshots.first['markdown'], '# hi');
  });
}
