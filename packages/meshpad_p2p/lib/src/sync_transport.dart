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
  PeerDiscovered({
    required this.peerId,
    required this.displayName,
    this.lanHost,
    this.httpPort,
  });
  final String peerId;
  final String displayName;
  final String? lanHost;
  final int? httpPort;
}

/// Emitted when a previously discovered peer is dropped (TTL or host dedupe).
class PeerExpired extends SyncTransportEvent {
  PeerExpired({required this.peerId});
  final String peerId;
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

/// Emitted on the host when a remote peer completes PIN pairing via HTTP confirm.
class PairingConfirmedRemotely extends SyncTransportEvent {
  PairingConfirmedRemotely({
    required this.initiatorPeerId,
    this.initiatorDisplayName,
  });

  final String initiatorPeerId;
  final String? initiatorDisplayName;
}
