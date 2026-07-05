import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('orderPeersForSync prefers online hub before offline peers', () {
    final transport = LanSyncTransport(
      getEngine: () async => throw UnimplementedError(),
      getIdentity: () async => throw UnimplementedError(),
    );
    transport.rememberEndpoint(
      const LanPeerEndpoint(
        peerId: 'online-hub',
        displayName: 'MeshPad Hub',
        host: '127.0.0.1',
        httpPort: 45838,
      ),
    );
    transport.rememberEndpoint(
      const LanPeerEndpoint(
        peerId: 'online-phone',
        displayName: 'Phone',
        host: '127.0.0.1',
        httpPort: 45839,
      ),
    );

    final peers = [
      Device(
        peerId: 'offline-pc',
        name: 'Desktop',
        lastSeenAt: DateTime.utc(2026, 1, 3),
      ),
      Device(
        peerId: 'online-hub',
        name: 'MeshPad Hub',
        lastSeenAt: DateTime.utc(2026, 1, 1),
      ),
      Device(
        peerId: 'online-phone',
        name: 'Phone',
        lastSeenAt: DateTime.utc(2026, 1, 2),
      ),
    ];

    final ordered = orderPeersForSync(peers: peers, transport: transport);

    expect(ordered.map((peer) => peer.peerId).toList(), [
      'online-hub',
      'online-phone',
      'offline-pc',
    ]);
    transport.dispose();
  });
}
