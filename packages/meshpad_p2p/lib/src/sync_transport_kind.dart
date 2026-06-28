/// Native sync transport selection (PLAN §12 B.3).
enum SyncTransportKind {
  /// Interim LAN HTTP + mDNS/UDP (MVP default).
  lan,

  /// @deprecated libp2p removed from production (ADR 0003). Maps to [lan].
  libp2p,
}

SyncTransportKind syncTransportKindFromWire(String? raw) {
  if (raw == 'libp2p') return SyncTransportKind.lan;
  return SyncTransportKind.lan;
}

String syncTransportKindToWire(SyncTransportKind kind) =>
    kind == SyncTransportKind.libp2p ? 'libp2p' : 'lan';
