/// Abstraction over libp2p (real) or in-memory fake for tests.
abstract class SyncTransport {
  Future<void> start();
  Future<void> stop();

  /// Emits peer discovery / sync completion events.
  Stream<SyncTransportEvent> get events;

  Future<void> requestSync({String? peerId});
}

sealed class SyncTransportEvent {}

class PeerDiscovered extends SyncTransportEvent {
  PeerDiscovered({required this.peerId, required this.displayName});
  final String peerId;
  final String displayName;
}

class SyncCompleted extends SyncTransportEvent {
  SyncCompleted({required this.peerId, this.noteCount = 0});
  final String peerId;
  final int noteCount;
}

class SyncFailed extends SyncTransportEvent {
  SyncFailed({this.peerId, required this.message});
  final String? peerId;
  final String message;
}
