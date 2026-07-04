import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';
import 'package:test/test.dart';

void main() {
  test('batch export/import round-trip on sidecar', () async {
    final sidecar = Libp2pSidecarServer(enableDiscovery: false);
    final server = await serveLibp2pSidecar(server: sidecar, port: 0);
    addTearDown(() async {
      await server.close(force: true);
      await sidecar.close();
    });

    final storeA = Libp2pSidecarWireStore();
    storeA.upsertSnapshot({
      'meta': {
        'schema_version': 2,
        'id': 'batch-note',
        'title': 'T',
        'author': 'a',
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-01T01:00:00.000Z',
        'deleted': false,
      },
      'markdown': 'x',
    });
    storeA.upsertAttachment(
      noteId: 'batch-note',
      name: 'pic.png',
      bytes: [1, 2, 3],
    );

    final clientB =
        Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final imported = await clientB.importBatch(storeA.exportBatch());
    expect(imported, greaterThan(0));

    final pulled = await clientB.exportBatch();
    expect(pulled.notes, hasLength(1));
    expect(pulled.notes.first['meta']['id'], 'batch-note');
    expect(pulled.attachments, hasLength(1));
  });

  test('importFromRemote prefers batch export', () async {
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

    final clientA =
        Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${serverA.port}');
    await clientA.pushSnapshot(
      snapshot: {
        'meta': {
          'schema_version': 2,
          'id': 'via-batch',
          'title': 'B',
          'author': 'a',
          'created_at': '2026-06-01T00:00:00.000Z',
          'updated_at': '2026-06-01T01:00:00.000Z',
          'deleted': false,
        },
        'markdown': 'batch path',
      },
    );

    final local = Libp2pSidecarWireStore();
    final remote =
        Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${serverA.port}');
    final count = await local.importFromRemote(remote);
    expect(count, 1);
    expect(local.pullSnapshots(['via-batch']), hasLength(1));
  });
}
