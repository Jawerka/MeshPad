import 'dart:convert';

import 'libp2p_sidecar_wire_batch.dart';
import 'libp2p_sidecar_wire_client.dart';

/// In-memory note store for sidecar `/v1/wire/*` (PLAN 8.1 dev harness).
///
/// Until libp2p transports payloads, this lets wire clients round-trip snapshots
/// without LAN. Production sync remains [LanSyncTransport].
/// Dev harness limit per attachment on sidecar wire (PLAN 8.1).
const maxSidecarWireAttachmentBytes = 16 * 1024 * 1024;

class Libp2pSidecarWireStore {
  final Map<String, Map<String, dynamic>> _snapshots = {};
  final Map<String, List<int>> _attachments = {};

  int get noteCount => _snapshots.length;

  int get attachmentCount => _attachments.length;

  static String attachmentKey(String noteId, String name) => '$noteId\x00$name';

  void upsertSnapshot(Map<String, dynamic> snapshot) {
    final id = noteIdFromWireSnapshot(snapshot);
    if (id == null || id.isEmpty) return;
    _snapshots[id] = _deepCopyMap(snapshot);
  }

  List<Map<String, dynamic>> catalogHeadsJson() {
    return _snapshots.entries.map((entry) {
      final meta = entry.value['meta'] as Map<String, dynamic>? ?? {};
      return {
        'id': entry.key,
        'updated_at':
            meta['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
        'deleted': meta['deleted'] as bool? ?? false,
      };
    }).toList();
  }

  List<Map<String, dynamic>> pullSnapshots(List<String> noteIds) {
    if (noteIds.isEmpty) {
      return _snapshots.values.map(_deepCopyMap).toList();
    }
    final out = <Map<String, dynamic>>[];
    for (final id in noteIds) {
      final snap = _snapshots[id];
      if (snap != null) out.add(_deepCopyMap(snap));
    }
    return out;
  }

  void clear() {
    _snapshots.clear();
    _attachments.clear();
  }

  bool upsertAttachment({
    required String noteId,
    required String name,
    required List<int> bytes,
  }) {
    if (noteId.isEmpty || name.isEmpty) return false;
    if (bytes.length > maxSidecarWireAttachmentBytes) return false;
    _attachments[attachmentKey(noteId, name)] = List<int>.from(bytes);
    return true;
  }

  List<int>? pullAttachment({required String noteId, required String name}) {
    return _attachments[attachmentKey(noteId, name)];
  }

  /// Imports [WireSyncBatch] envelope (notes + attachments).
  int importBatch(WireSyncBatch batch) {
    if (batch.version != 1) return 0;
    var count = 0;
    for (final snapshot in batch.notes) {
      upsertSnapshot(snapshot);
      count++;
    }
    for (final attachment in batch.attachments) {
      if (attachment.noteId.isEmpty || attachment.name.isEmpty) continue;
      if (attachment.bytesBase64.isEmpty) continue;
      final bytes = base64Decode(attachment.bytesBase64);
      if (upsertAttachment(
        noteId: attachment.noteId,
        name: attachment.name,
        bytes: bytes,
      )) {
        count++;
      }
    }
    return count;
  }

  WireSyncBatch exportBatch() {
    final attachments = <WireBatchAttachment>[];
    for (final entry in _attachments.entries) {
      final sep = entry.key.indexOf('\x00');
      if (sep < 0) continue;
      attachments.add(
        WireBatchAttachment(
          noteId: entry.key.substring(0, sep),
          name: entry.key.substring(sep + 1),
          bytesBase64: base64Encode(entry.value),
        ),
      );
    }
    return WireSyncBatch(
      version: 1,
      catalog: catalogHeadsJson(),
      notes: pullSnapshots(const []),
      attachments: attachments,
    );
  }

  /// Pulls all snapshots from another sidecar wire API (PLAN 8.2 dev harness).
  Future<int> importFromRemote(Libp2pSidecarWireClient remote) async {
    try {
      final batch = await remote.exportBatch();
      final imported = importBatch(batch);
      if (imported > 0) return imported;
    } on Object {
      // Remote may not support batch export — fall back.
    }

    final heads = await remote.fetchCatalog();
    if (heads.isEmpty) return 0;

    final pull = await remote.pullNotes(
      noteIds: [for (final head in heads) head.id],
    );
    for (final snapshot in pull.snapshots) {
      upsertSnapshot(snapshot);
    }
    return pull.snapshots.length;
  }

  /// Pushes all local snapshots to another sidecar wire API (bidirectional sync).
  Future<int> pushToRemote(Libp2pSidecarWireClient remote) async {
    if (_snapshots.isEmpty) return 0;
    var pushed = 0;
    for (final snapshot in _snapshots.values) {
      final result =
          await remote.pushSnapshot(snapshot: _deepCopyMap(snapshot));
      if (result.status == 'accepted') pushed++;
    }
    return pushed;
  }
}

String? noteIdFromWireSnapshot(Map<String, dynamic> snapshot) {
  final meta = snapshot['meta'];
  if (meta is! Map) return null;
  final id = meta['id'];
  return id is String ? id : id?.toString();
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> source) {
  return Map<String, dynamic>.from(
    source.map((key, value) {
      if (value is Map) {
        return MapEntry(key, Map<String, dynamic>.from(value));
      }
      if (value is List) {
        return MapEntry(key, List<dynamic>.from(value));
      }
      return MapEntry(key, value);
    }),
  );
}
