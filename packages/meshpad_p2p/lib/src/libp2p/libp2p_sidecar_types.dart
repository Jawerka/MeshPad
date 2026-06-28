/// Health payload from sidecar `GET /health`.
class Libp2pSidecarHealth {
  const Libp2pSidecarHealth({
    required this.ok,
    this.backend,
    this.httpPort,
    this.running = false,
    this.wireNotes = 0,
  });

  final bool ok;
  final String? backend;
  final int? httpPort;
  final bool running;
  final int wireNotes;

  bool get isRustLibp2p => backend == 'rust-libp2p';

  factory Libp2pSidecarHealth.fromJson(Map<String, dynamic> json) {
    return Libp2pSidecarHealth(
      ok: json['status'] == 'ok',
      backend: json['backend'] as String?,
      httpPort: json['http_port'] as int?,
      running: json['running'] as bool? ?? false,
      wireNotes: json['wire_notes'] as int? ?? 0,
    );
  }
}

/// Response from sidecar `POST /v1/sync`.
class Libp2pSidecarSyncResult {
  const Libp2pSidecarSyncResult({
    this.wireImported = 0,
    this.wirePushed = 0,
    this.importVia,
    this.lanFallback = true,
  });

  final int wireImported;
  final int wirePushed;
  final String? importVia;
  final bool lanFallback;

  /// Sidecar replicated wire notes with the remote peer (HTTP or libp2p).
  bool get replicatedRemotely =>
      !lanFallback &&
      (wireImported > 0 ||
          wirePushed > 0 ||
          importVia == 'libp2p' ||
          importVia == 'http_wire_base');

  factory Libp2pSidecarSyncResult.fromJson(Map<String, dynamic> json) {
    return Libp2pSidecarSyncResult(
      wireImported: json['wire_imported'] as int? ?? 0,
      wirePushed: json['wire_pushed'] as int? ?? 0,
      importVia: json['import_via'] as String?,
      lanFallback: json['lan_fallback'] as bool? ?? true,
    );
  }
}
