import 'dart:async';

import 'sync_transport.dart';

/// No-op transport for UI and core tests before libp2p is integrated.
class FakeSyncTransport implements SyncTransport {
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
    _controller.add(SyncCompleted(peerId: peerId ?? 'fake-peer', noteCount: 0));
  }

  void dispose() => _controller.close();
}
