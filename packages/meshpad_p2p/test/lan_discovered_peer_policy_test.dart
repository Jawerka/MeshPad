import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  group('pickPreferredPeerOnHost', () {
    test('prefers stable HTTP port over ephemeral test ports', () {
      final now = DateTime.utc(2026, 7, 4, 12);
      final onHost = [
        MapEntry(
          'ephemeral',
          const LanPeerEndpoint(
            peerId: 'ephemeral',
            displayName: 'Test',
            host: '192.168.88.48',
            httpPort: 39577,
          ),
        ),
        MapEntry(
          'hub',
          const LanPeerEndpoint(
            peerId: 'hub',
            displayName: 'MeshPad Hub',
            host: '192.168.88.48',
            httpPort: meshpadPreferredLanHttpPort,
          ),
        ),
      ];

      final picked = pickPreferredPeerOnHost(
        onHost,
        lastSeenByPeerId: {
          'ephemeral': now,
          'hub': now.subtract(const Duration(minutes: 5)),
        },
      );

      expect(picked.peerId, 'hub');
    });

    test('prefers most recently seen when ports match', () {
      final now = DateTime.utc(2026, 7, 4, 12);
      final onHost = [
        MapEntry(
          'old',
          const LanPeerEndpoint(
            peerId: 'old',
            displayName: 'Old',
            host: '192.168.88.5',
            httpPort: 55658,
          ),
        ),
        MapEntry(
          'new',
          const LanPeerEndpoint(
            peerId: 'new',
            displayName: 'New',
            host: '192.168.88.5',
            httpPort: 55681,
          ),
        ),
      ];

      final picked = pickPreferredPeerOnHost(
        onHost,
        lastSeenByPeerId: {
          'old': now.subtract(const Duration(minutes: 10)),
          'new': now,
        },
      );

      expect(picked.peerId, 'new');
    });
  });

  group('stalePeerIds', () {
    test('returns peers older than ttl', () {
      final now = DateTime.utc(2026, 7, 4, 12);
      final stale = stalePeerIds(
        lastSeenByPeerId: {
          'fresh': now.subtract(const Duration(minutes: 5)),
          'old': now.subtract(const Duration(minutes: 20)),
        },
        ttl: const Duration(minutes: 15),
        now: now,
      ).toList();

      expect(stale, ['old']);
    });
  });
}
