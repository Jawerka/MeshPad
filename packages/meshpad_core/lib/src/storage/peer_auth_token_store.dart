/// Stores LAN sync auth tokens outside `trusted/*.json` when configured (PLAN §11.2.1).
abstract class PeerAuthTokenStore {
  Future<String?> read(String peerId);

  Future<void> write(String peerId, String token);

  Future<void> delete(String peerId);
}

/// Tokens live only in trusted JSON (tests, legacy headless without migration).
class EmbeddedPeerAuthTokenStore implements PeerAuthTokenStore {
  const EmbeddedPeerAuthTokenStore();

  @override
  Future<String?> read(String peerId) async => null;

  @override
  Future<void> write(String peerId, String token) async {}

  @override
  Future<void> delete(String peerId) async {}
}
