import 'package:meshpad_p2p/src/lan/lan_broadcast.dart';
import 'package:test/test.dart';

void main() {
  group('pickPreferredLanHost', () {
    test('prefers 192.168 over VPN 10.x', () {
      expect(
        pickPreferredLanHost(['10.8.0.7', '192.168.88.5']),
        '192.168.88.5',
      );
    });

    test('skips VirtualBox host-only', () {
      expect(
        pickPreferredLanHost(['192.168.56.1', '192.168.88.5']),
        '192.168.88.5',
      );
    });

    test('skips VPN-only addresses', () {
      expect(
        pickPreferredLanHost(['10.8.0.7']),
        isNull,
      );
    });
  });

  group('isLikelyVpnOnlyIp', () {
    test('treats 10.x as VPN overlay', () {
      expect(isLikelyVpnOnlyIp('10.8.0.7'), isTrue);
      expect(isLikelyVpnOnlyIp('192.168.88.5'), isFalse);
    });
  });

  group('isVpnOrTunnelInterface', () {
    test('matches common tunnel names', () {
      expect(isVpnOrTunnelInterface('Tailscale Tunnel'), isTrue);
      expect(isVpnOrTunnelInterface('WireGuard Tunnel'), isTrue);
      expect(isVpnOrTunnelInterface('Ethernet'), isFalse);
    });
  });

  group('subnetBroadcastAddress', () {
    test('builds /24 broadcast', () {
      expect(subnetBroadcastAddress('192.168.88.5'), '192.168.88.255');
    });
  });

  group('computeBroadcastTargets', () {
    test('with lanHost limits to home subnet', () async {
      final targets = await computeBroadcastTargets(lanHost: '192.168.88.5');
      expect(
        targets.map((a) => a.address).toList(),
        ['255.255.255.255', '192.168.88.255'],
      );
    });
  });
}
