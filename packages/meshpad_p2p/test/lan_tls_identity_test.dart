import 'dart:io';

import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

import 'package:meshpad_p2p/src/lan/lan_tls_identity.dart';

void main() {
  test('loadOrCreate is safe under concurrent calls', () async {
    final dir = await Directory.systemTemp.createTemp('meshpad_tls_race_');
    final results = await Future.wait(
      List.generate(8, (_) => LanTlsIdentity.loadOrCreate(dir)),
    );
    final hash = results.first.certSha256Hex;
    for (final identity in results) {
      expect(identity.certSha256Hex, hash);
    }
  });

  test('loadOrCreate generates stable TLS identity', () async {
    final dir = await Directory.systemTemp.createTemp('meshpad_tls_');
    final first = await LanTlsIdentity.loadOrCreate(dir);
    final second = await LanTlsIdentity.loadOrCreate(dir);
    expect(first.certSha256Hex, second.certSha256Hex);
    expect(first.certSha256Hex, hasLength(64));
  });

  test('pinned client accepts matching certificate', () async {
    final dir = await Directory.systemTemp.createTemp('meshpad_tls_srv_');
    final identity = await LanTlsIdentity.loadOrCreate(dir);
    final server = LanPeerServer(
      preferredPort: 0,
      getEngine: () async => throw UnimplementedError(),
      tlsIdentity: identity,
    );
    final httpPort = await server.start(address: InternetAddress.loopbackIPv4);
    final tlsPort = server.tlsPort;
    expect(tlsPort, isNotNull);

    final endpoint = LanPeerEndpoint(
      peerId: 'peer-a',
      displayName: 'A',
      host: '127.0.0.1',
      httpPort: httpPort,
      tlsPort: tlsPort,
    );
    final gateway = HttpRemoteSyncGateway(
      endpoint: endpoint,
      tlsCertSha256: identity.certSha256Hex,
    );
    expect(await gateway.checkHealth(secure: true), isTrue);
    await server.stop();
  });
}
