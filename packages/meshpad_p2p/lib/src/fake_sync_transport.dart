import 'dart:async';

import 'package:meshpad_core/meshpad_core.dart';

import 'sync_transport.dart';

/// In-memory registry for pairing fake transports in tests.
class FakeSyncHub {
  final _engines = <String, SyncEngine>{};

  void register(String peerId, SyncEngine engine) {
    _engines[peerId] = engine;
  }

  void unregister(String peerId) => _engines.remove(peerId);

  Future<SyncSessionResult> syncPeers(String localPeerId, String remotePeerId) {
    final local = _engines[localPeerId];
    final remote = _engines[remotePeerId];
    if (local == null || remote == null) {
      throw StateError('Peer not registered: $localPeerId or $remotePeerId');
    }
    return local.syncWith(remote);
  }
}

/// No-op transport; can run paired sync via [FakeSyncHub].
class FakeSyncTransport implements SyncTransport {
  FakeSyncTransport({
    this.hub,
    this.localPeerId,
    this.remotePeerId,
    this.onSyncRequested,
  });

  final FakeSyncHub? hub;
  final String? localPeerId;
  final String? remotePeerId;
  final Future<int> Function()? onSyncRequested;

  final _controller = StreamController<SyncTransportEvent>.broadcast();
  var _running = false;

  @override
  Stream<SyncTransportEvent> get events => _controller.stream;

  @override
  Future<void> start() async {
    _running = true;
  }

  @override
  Future<void> stop() async {
    _running = false;
  }

  @override
  Future<void> requestSync({String? peerId}) async {
    if (!_running) return;

    var noteCount = 0;
    if (hub != null &&
        localPeerId != null &&
        (peerId ?? remotePeerId) != null) {
      final target = peerId ?? remotePeerId!;
      final result = await hub!.syncPeers(localPeerId!, target);
      noteCount = result.total;
    } else {
      noteCount = await onSyncRequested?.call() ?? 0;
    }

    _controller.add(
      SyncCompleted(peerId: peerId ?? remotePeerId ?? 'fake-peer', noteCount: noteCount),
    );
  }

  void emitPeerDiscovered({required String peerId, required String displayName}) {
    _controller.add(PeerDiscovered(peerId: peerId, displayName: displayName));
  }

  void dispose() => _controller.close();
}
