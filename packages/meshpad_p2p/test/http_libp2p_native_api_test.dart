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
    sidecar = Libp2pSidecarServer();
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
    await api.requestSync(peerId: 'peer-x');
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
