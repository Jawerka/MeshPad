import 'dart:convert';

import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('POST /v1/start returns started', () async {
    final sidecar = Libp2pSidecarServer();
    final router = sidecar.buildRouter();

    final start = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/start'),
        body: jsonEncode({'peer_id': 'p1', 'display_name': 'Node'}),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(start.statusCode, 200);
    expect(await start.readAsString(), contains('started'));
    await sidecar.close();
  });

  test('GET /health reports dart-mdns backend', () async {
    final sidecar = Libp2pSidecarServer();
    final router = sidecar.buildRouter();

    final health = await router.call(
      Request('GET', Uri.parse('http://localhost/health')),
    );
    expect(health.statusCode, 200);
    expect(await health.readAsString(), contains('dart-mdns'));
    await sidecar.close();
  });
}
