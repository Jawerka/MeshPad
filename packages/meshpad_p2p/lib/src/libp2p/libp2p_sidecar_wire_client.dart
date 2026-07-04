import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';

import 'http_libp2p_native_api.dart';
import 'http_sidecar_json_transport.dart';
import 'libp2p_sidecar_wire_batch.dart';
import 'sidecar_json_transport.dart';

/// Result of `POST /v1/wire/push` on the libp2p sidecar (PLAN 8.1).
class Libp2pWirePushResult {
  const Libp2pWirePushResult({
    required this.status,
    this.lanFallback = true,
    this.peerId,
  });

  final String status;
  final bool lanFallback;
  final String? peerId;

  factory Libp2pWirePushResult.fromJson(Map<String, dynamic> json) {
    return Libp2pWirePushResult(
      status: json['status'] as String? ?? 'unknown',
      lanFallback: json['lan_fallback'] as bool? ?? true,
      peerId: json['peer_id'] as String?,
    );
  }
}

/// Result of `POST /v1/wire/pull` on the libp2p sidecar (PLAN 8.1).
class Libp2pWirePullResult {
  const Libp2pWirePullResult({
    required this.status,
    this.lanFallback = true,
    this.peerId,
    this.noteIds = const [],
    this.snapshots = const [],
  });

  final String status;
  final bool lanFallback;
  final String? peerId;
  final List<String> noteIds;
  final List<Map<String, dynamic>> snapshots;

  factory Libp2pWirePullResult.fromJson(Map<String, dynamic> json) {
    final notes = json['notes'];
    return Libp2pWirePullResult(
      status: json['status'] as String? ?? 'unknown',
      lanFallback: json['lan_fallback'] as bool? ?? true,
      peerId: json['peer_id'] as String?,
      noteIds: (json['note_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      snapshots: notes is List<dynamic>
          ? notes
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const [],
    );
  }
}

/// Client for sidecar wire endpoints ([SYNC_WIRE.md] via `/v1/wire/*`).
class Libp2pSidecarWireClient {
  Libp2pSidecarWireClient({
    String baseUrl = defaultLibp2pSidecarUrl,
    HttpClient? httpClient,
    SidecarJsonTransport? transport,
  }) : _transport = transport ??
            HttpSidecarJsonTransport(
              baseUrl: baseUrl,
              httpClient: httpClient,
            );

  final SidecarJsonTransport _transport;

  /// `GET /v1/wire/batch/export` — full wire batch envelope (PLAN 8.1).
  Future<WireSyncBatch> exportBatch() async {
    final body = await _transport.getJson('/v1/wire/batch/export');
    return WireSyncBatch.fromJson(body);
  }

  /// `POST /v1/wire/batch/import` — import batch envelope.
  Future<int> importBatch(WireSyncBatch batch) async {
    final json =
        await _transport.postJson('/v1/wire/batch/import', batch.toJson());
    return json['imported'] as int? ?? 0;
  }

  /// `GET /v1/wire/catalog` — note heads (same JSON as LAN catalog).
  Future<List<NoteHead>> fetchCatalog() async {
    final decoded = await _transport.getValue('/v1/wire/catalog');
    if (decoded is! List<dynamic>) {
      throw FormatException('expected JSON array from /v1/wire/catalog');
    }
    return noteHeadsFromJsonList(decoded);
  }

  /// `POST /v1/wire/push` — push one [RemoteNoteSnapshot]-shaped map.
  Future<Libp2pWirePushResult> pushSnapshot({
    required Map<String, dynamic> snapshot,
    String? peerId,
  }) async {
    final json = await _transport.postJson('/v1/wire/push', {
      if (peerId != null) 'peer_id': peerId,
      'snapshot': snapshot,
    });
    return Libp2pWirePushResult.fromJson(json);
  }

  /// `POST /v1/wire/attachment/push` — store attachment bytes (base64 JSON).
  Future<bool> pushAttachment({
    required String noteId,
    required String name,
    required List<int> bytes,
    String? peerId,
  }) async {
    final json = await _transport.postJson('/v1/wire/attachment/push', {
      if (peerId != null) 'peer_id': peerId,
      'note_id': noteId,
      'name': name,
      'bytes_base64': base64Encode(bytes),
    });
    return json['status'] == 'accepted';
  }

  /// `POST /v1/wire/attachment/pull` — returns bytes or null when missing.
  Future<List<int>?> pullAttachment({
    required String noteId,
    required String name,
    String? peerId,
  }) async {
    try {
      final json = await _transport.postJson('/v1/wire/attachment/pull', {
        if (peerId != null) 'peer_id': peerId,
        'note_id': noteId,
        'name': name,
      });
      if (json['status'] == 'not_found') return null;
      final encoded = json['bytes_base64'] as String?;
      if (encoded == null || encoded.isEmpty) return null;
      return base64Decode(encoded);
    } catch (e) {
      if (e is HttpException && e.message.contains('404')) return null;
      rethrow;
    }
  }

  /// `POST /v1/wire/pull` — request note bodies by id.
  Future<Libp2pWirePullResult> pullNotes({
    required List<String> noteIds,
    String? peerId,
  }) async {
    final json = await _transport.postJson('/v1/wire/pull', {
      if (peerId != null) 'peer_id': peerId,
      'note_ids': noteIds,
    });
    return Libp2pWirePullResult.fromJson(json);
  }
}
