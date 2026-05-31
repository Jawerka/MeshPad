/// Dart-side contract for the future native libp2p bridge (PLAN §12 B.1–B.2).
///
/// Implementation target: Rust `rust-libp2p` crate exposed via FFI or gRPC on
/// localhost. See [docs/LIBP2P.md](../../../../docs/LIBP2P.md).
abstract class Libp2pNativeApi {
  Future<void> start({
    required String peerId,
    required String displayName,
  });

  Future<void> stop();

  Stream<Libp2pNativeEvent> get events;

  Future<void> requestSync({String? peerId});
}

sealed class Libp2pNativeEvent {}

class Libp2pNativePeerDiscovered extends Libp2pNativeEvent {
  Libp2pNativePeerDiscovered({
    required this.peerId,
    required this.displayName,
    this.lanHost,
    this.httpPort,
    this.tlsPort,
  });

  final String peerId;
  final String displayName;
  final String? lanHost;
  final int? httpPort;
  final int? tlsPort;
}

class Libp2pNativeSyncCompleted extends Libp2pNativeEvent {
  Libp2pNativeSyncCompleted({required this.peerId, this.noteCount = 0});

  final String peerId;
  final int noteCount;
}

class Libp2pNativeSyncFailed extends Libp2pNativeEvent {
  Libp2pNativeSyncFailed({this.peerId, required this.message});

  final String? peerId;
  final String message;
}
