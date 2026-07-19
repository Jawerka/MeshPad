import 'package:meshpad_p2p/src/lan/lan_broadcast.dart';
import 'package:test/test.dart';

void main() {
  group('isUsableRemoteLanHost', () {
    test('accepts private LAN', () {
      expect(isUsableRemoteLanHost('192.168.88.5'), isTrue);
      expect(isUsableRemoteLanHost('10.0.0.2'), isTrue);
      expect(isUsableRemoteLanHost('172.16.1.1'), isTrue);
    });

    test('rejects loopback and link-local', () {
      expect(isUsableRemoteLanHost('127.0.0.1'), isFalse);
      expect(isUsableRemoteLanHost('localhost'), isFalse);
      expect(isUsableRemoteLanHost('169.254.1.1'), isFalse);
      expect(isUsableRemoteLanHost(''), isFalse);
    });
  });

  group('preferredLanHost', () {
    test('never prefers loopback over private LAN', () {
      expect(
        preferredLanHost('127.0.0.1', '192.168.88.5'),
        '192.168.88.5',
      );
      expect(
        preferredLanHost('192.168.88.5', '127.0.0.1'),
        '192.168.88.5',
      );
    });
  });

  group('shouldTryStoredLanEndpoint', () {
    test('rejects stored loopback when local is private LAN', () {
      expect(
        shouldTryStoredLanEndpoint(
          storedHost: '127.0.0.1',
          localHost: '192.168.88.48',
        ),
        isFalse,
      );
    });

    test('allows stored loopback when local is also loopback', () {
      expect(
        shouldTryStoredLanEndpoint(
          storedHost: '127.0.0.1',
          localHost: '127.0.0.1',
        ),
        isTrue,
      );
    });

    test('allows same /24 private hosts', () {
      expect(
        shouldTryStoredLanEndpoint(
          storedHost: '192.168.88.5',
          localHost: '192.168.88.48',
        ),
        isTrue,
      );
    });
  });

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
