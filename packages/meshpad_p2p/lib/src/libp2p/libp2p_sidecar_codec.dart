import 'dart:convert';

import 'libp2p_native_api.dart';

/// JSON wire format for libp2p sidecar SSE events (B.2).
Map<String, dynamic> libp2pSidecarEventToJson(Libp2pNativeEvent event) {
  return switch (event) {
    Libp2pNativePeerDiscovered(
      :final peerId,
      :final displayName,
      :final lanHost,
      :final httpPort,
      :final tlsPort,
    ) =>
        {
        'type': 'peer_discovered',
        'peer_id': peerId,
        'display_name': displayName,
        if (lanHost != null) 'lan_host': lanHost,
        if (httpPort != null) 'http_port': httpPort,
        if (tlsPort != null) 'tls_port': tlsPort,
      },
    Libp2pNativeSyncCompleted(:final peerId, :final noteCount) => {
        'type': 'sync_completed',
        'peer_id': peerId,
        'note_count': noteCount,
      },
    Libp2pNativeSyncFailed(:final peerId, :final message) => {
        'type': 'sync_failed',
        if (peerId != null) 'peer_id': peerId,
        'message': message,
      },
  };
}

Libp2pNativeEvent libp2pSidecarEventFromJson(Map<String, dynamic> json) {
  return switch (json['type']) {
    'peer_discovered' => Libp2pNativePeerDiscovered(
        peerId: json['peer_id'] as String,
        displayName: json['display_name'] as String? ?? 'Устройство',
        lanHost: json['lan_host'] as String?,
        httpPort: json['http_port'] as int?,
        tlsPort: json['tls_port'] as int?,
      ),
    'sync_completed' => Libp2pNativeSyncCompleted(
        peerId: json['peer_id'] as String,
        noteCount: json['note_count'] as int? ?? 0,
      ),
    'sync_failed' => Libp2pNativeSyncFailed(
        peerId: json['peer_id'] as String?,
        message: json['message'] as String? ?? 'sync failed',
      ),
    _ => Libp2pNativeSyncFailed(message: 'unknown sidecar event'),
  };
}

Stream<Libp2pNativeEvent> parseLibp2pSidecarEventStream(Stream<String> lines) async* {
  await for (final line in lines) {
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trimLeft();
    if (payload.isEmpty) continue;
    yield libp2pSidecarEventFromJson(
      jsonDecode(payload) as Map<String, dynamic>,
    );
  }
}
