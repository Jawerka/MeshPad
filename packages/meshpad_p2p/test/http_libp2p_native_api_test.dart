import 'dart:convert';
import 'dart:io';

import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';
import 'package:shelf/shelf.dart';
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

  test('health returns ok', () async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/health'));
    final response = await request.close();
    expect(response.statusCode, 200);
    client.close();
  });

  test('HttpLibp2pNativeApi start and requestSync', () async {
    final api = HttpLibp2pNativeApi(baseUrl: 'http://127.0.0.1:$port');
    expect(await api.checkHealth(), isTrue);

    await api.start(peerId: 'local', displayName: 'Local');
    final health = await api.fetchHealth();
    expect(health?.ok, isTrue);
    expect(health?.backend, 'dart-mdns');

    final sync = await api.requestSyncWithResult(peerId: 'peer-x');
    expect(sync.lanFallback, isFalse);
  });

  test('sidecar sync_completed on SSE stream', () async {
    final sidecar = Libp2pSidecarServer(enableDiscovery: false);
    final router = sidecar.buildRouter();

    final sseBody = () async {
      final response = await router.call(
        Request('GET', Uri.parse('http://localhost/v1/events')),
      );
      expect(response.statusCode, 200);
      final buffer = StringBuffer();
      await for (final chunk in response.read()) {
        buffer.write(utf8.decode(chunk));
        if (buffer.toString().contains('sync_completed')) {
          return buffer.toString();
        }
      }
      return buffer.toString();
    }();

    await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/start'),
        body: jsonEncode({'peer_id': 'p1', 'display_name': 'Test'}),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    final sync = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/sync'),
        body: jsonEncode({'peer_id': 'remote-peer'}),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(sync.statusCode, 200);

    final body = await sseBody.timeout(const Duration(seconds: 2));
    expect(body, contains('"type":"sync_completed"'));
    expect(body, contains('remote-peer'));

    await sidecar.close();
  });

  test('two sidecars run start and sync independently', () async {
    final sidecarA = Libp2pSidecarServer(enableDiscovery: false);
    final sidecarB = Libp2pSidecarServer(enableDiscovery: false);
    final serverA = await serveLibp2pSidecar(server: sidecarA, port: 0);
    final serverB = await serveLibp2pSidecar(server: sidecarB, port: 0);

    Future<int> postJson(int port, String path, Map<String, dynamic> body) async {
      final client = HttpClient();
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1:$port$path'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      client.close();
      return response.statusCode;
    }

    expect(
      await postJson(serverA.port, '/v1/start', {
        'peer_id': 'peer-a',
        'display_name': 'A',
      }),
      200,
    );
    expect(
      await postJson(serverB.port, '/v1/start', {
        'peer_id': 'peer-b',
        'display_name': 'B',
      }),
      200,
    );
    expect(
      await postJson(serverA.port, '/v1/sync', {'peer_id': 'peer-b'}),
      200,
    );
    expect(
      await postJson(serverB.port, '/v1/sync', {'peer_id': 'peer-a'}),
      200,
    );

    await serverA.close(force: true);
    await serverB.close(force: true);
    await sidecarA.close();
    await sidecarB.close();
  });

  test('two sidecars replicate wire notes via remote_wire_base', () async {
    final sidecarA = Libp2pSidecarServer(enableDiscovery: false);
    final sidecarB = Libp2pSidecarServer(enableDiscovery: false);
    final serverA = await serveLibp2pSidecar(server: sidecarA, port: 0);
    final serverB = await serveLibp2pSidecar(server: sidecarB, port: 0);

    final wireB = Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${serverB.port}');
    await wireB.pushSnapshot(
      snapshot: {
        'meta': {
          'schema_version': 2,
          'id': 'peer-b-note',
          'title': 'From B',
          'author': 'peer-b',
          'created_at': '2026-06-01T08:00:00.000Z',
          'updated_at': '2026-06-01T09:00:00.000Z',
          'deleted': false,
        },
        'markdown': '# replicated',
      },
    );

    final apiA = HttpLibp2pNativeApi(baseUrl: 'http://127.0.0.1:${serverA.port}');
    await apiA.start(peerId: 'peer-a', displayName: 'A');
    await apiA.requestSync(
      peerId: 'peer-b',
      remoteWireBase: 'http://127.0.0.1:${serverB.port}',
    );

    final wireA = Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:${serverA.port}');
    final catalogA = await wireA.fetchCatalog();
    expect(catalogA, hasLength(1));
    expect(catalogA.first.id, 'peer-b-note');

    final pullA = await wireA.pullNotes(noteIds: ['peer-b-note']);
    expect(pullA.snapshots.first['markdown'], '# replicated');

    await apiA.stop();
    await serverA.close(force: true);
    await serverB.close(force: true);
    await sidecarA.close();
    await sidecarB.close();
  });

  test('sidecar POST /v1/sync returns delegated', () async {
    final router = sidecar.buildRouter();
    await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/start'),
        body: jsonEncode({'peer_id': 'p1', 'display_name': 'Node'}),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    final sync = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/sync'),
        body: jsonEncode({'peer_id': 'remote'}),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(sync.statusCode, 200);
    expect(await sync.readAsString(), contains('delegated'));
  });
}
