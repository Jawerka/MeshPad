/// Native sync transport selection (PLAN §12 B.3).
enum SyncTransportKind {
  /// Interim LAN HTTP + mDNS/UDP (MVP default).
  lan,

  /// Native libp2p when available; until B.2 ships uses [LanSyncTransport] fallback.
  libp2p,
}

SyncTransportKind syncTransportKindFromWire(String? raw) {
  return raw == 'libp2p' ? SyncTransportKind.libp2p : SyncTransportKind.lan;
}

String syncTransportKindToWire(SyncTransportKind kind) =>
    kind == SyncTransportKind.libp2p ? 'libp2p' : 'lan';
