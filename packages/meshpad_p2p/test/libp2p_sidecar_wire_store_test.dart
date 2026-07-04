import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';
import 'package:test/test.dart';

void main() {
  test('upsert and catalog round-trip', () {
    final store = Libp2pSidecarWireStore();
    store.upsertSnapshot({
      'meta': {
        'id': 'n1',
        'updated_at': '2026-06-01T12:00:00.000Z',
        'deleted': false,
      },
      'markdown': 'hello',
    });

    final heads = store.catalogHeadsJson();
    expect(heads, hasLength(1));
    expect(heads.first['id'], 'n1');

    final pulled = store.pullSnapshots(['n1']);
    expect(pulled, hasLength(1));
    expect(pulled.first['markdown'], 'hello');
  });

  test('importFromRemote copies snapshots from another sidecar', () async {
    final sidecar = Libp2pSidecarServer(enableDiscovery: false);
    final server = await serveLibp2pSidecar(server: sidecar, port: 0);
    addTearDown(() async {
      await server.close(force: true);
      await sidecar.close();
    });

    final remote =
        Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${server.port}');
    await remote.pushSnapshot(
      snapshot: {
        'meta': {
          'schema_version': 2,
          'id': 'remote-1',
          'title': 'R',
          'author': 'x',
          'created_at': '2026-06-01T00:00:00.000Z',
          'updated_at': '2026-06-01T01:00:00.000Z',
          'deleted': false,
        },
        'markdown': 'remote body',
      },
    );

    final local = Libp2pSidecarWireStore();
    final count = await local.importFromRemote(remote);
    expect(count, 1);
    expect(local.pullSnapshots(['remote-1']).first['markdown'], 'remote body');
  });

  test('pushToRemote sends local snapshots to another sidecar', () async {
    final sidecar = Libp2pSidecarServer(enableDiscovery: false);
    final server = await serveLibp2pSidecar(server: sidecar, port: 0);
    addTearDown(() async {
      await server.close(force: true);
      await sidecar.close();
    });

    final remote =
        Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${server.port}');
    final local = Libp2pSidecarWireStore();
    local.upsertSnapshot({
      'meta': {
        'schema_version': 2,
        'id': 'local-1',
        'title': 'L',
        'author': 'x',
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-01T01:00:00.000Z',
        'deleted': false,
      },
      'markdown': 'local body',
    });

    final pushed = await local.pushToRemote(remote);
    expect(pushed, 1);
    final heads = await remote.fetchCatalog();
    expect(heads.map((h) => h.id), contains('local-1'));
  });
}
