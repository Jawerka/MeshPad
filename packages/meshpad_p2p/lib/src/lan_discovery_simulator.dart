import 'dart:async';

import 'fake_sync_transport.dart';
import 'sync_transport.dart';

/// Stub LAN/mDNS discovery until libp2p is integrated (PLAN §5.1).
class LanDiscoverySimulator {
  LanDiscoverySimulator(
    this._transport, {
    this.initialDelay = const Duration(seconds: 3),
  });

  final FakeSyncTransport _transport;
  final Duration initialDelay;

  Timer? _timer;
  var _started = false;

  /// Demo peers shown in the «Обнаруженные» UI section.
  static const demoPeers = [
    (peerId: 'lan-demo-phone', displayName: 'MeshPad · телефон'),
    (peerId: 'lan-demo-laptop', displayName: 'MeshPad · ноутбук'),
  ];

  void start() {
    if (_started) return;
    _started = true;

    _timer = Timer(initialDelay, () {
      for (final peer in demoPeers) {
        _transport.emitPeerDiscovered(
          peerId: peer.peerId,
          displayName: peer.displayName,
        );
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  void dispose() => stop();
}

/// Tracks peers reported by [SyncTransport] discovery events.
class DiscoveredPeer {
  const DiscoveredPeer({
    required this.peerId,
    required this.displayName,
    required this.discoveredAt,
  });

  final String peerId;
  final String displayName;
  final DateTime discoveredAt;

  factory DiscoveredPeer.fromEvent(PeerDiscovered event) {
    return DiscoveredPeer(
      peerId: event.peerId,
      displayName: event.displayName,
      discoveredAt: DateTime.now().toUtc(),
    );
  }
}
