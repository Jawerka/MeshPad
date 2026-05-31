import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('libp2pSidecarEvent round-trip', () {
    final event = Libp2pNativePeerDiscovered(
      peerId: 'peer-1',
      displayName: 'Desk',
      lanHost: '192.168.1.10',
      httpPort: 45838,
      tlsPort: 45840,
    );
    final json = libp2pSidecarEventToJson(event);
    expect(json['lan_host'], '192.168.1.10');
    expect(json['http_port'], 45838);
    expect(json['tls_port'], 45840);

    final restored = libp2pSidecarEventFromJson(json);
    expect(restored, isA<Libp2pNativePeerDiscovered>());
    final peer = restored as Libp2pNativePeerDiscovered;
    expect(peer.peerId, 'peer-1');
    expect(peer.lanHost, '192.168.1.10');
    expect(peer.httpPort, 45838);
    expect(peer.tlsPort, 45840);
  });
}
