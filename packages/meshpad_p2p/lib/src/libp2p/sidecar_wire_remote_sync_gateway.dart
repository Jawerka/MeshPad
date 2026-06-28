import 'package:meshpad_core/meshpad_core.dart';

import 'libp2p_sidecar_wire_client.dart';

/// [RemoteSyncGateway] backed by the local libp2p sidecar `/v1/wire/*` API (PLAN 8.3).
///
/// The sidecar is expected to hold the remote peer's catalog/snapshots after
/// native `POST /v1/sync` (libp2p data plane). Attachments via `/v1/wire/attachment/*`.
class SidecarWireRemoteSyncGateway implements RemoteSyncGateway {
  SidecarWireRemoteSyncGateway({
    required Libp2pSidecarWireClient client,
    this.peerId,
  }) : _client = client;

  final Libp2pSidecarWireClient _client;
  final String? peerId;

  @override
  Future<List<NoteHead>> fetchCatalog() => _client.fetchCatalog();

  @override
  Future<RemoteNoteSnapshot?> fetchNote(String id) async {
    final pull = await _client.pullNotes(peerId: peerId, noteIds: [id]);
    if (pull.snapshots.isEmpty) return null;
    return remoteSnapshotFromJson(pull.snapshots.first);
  }

  @override
  Future<NoteApplyResult> pushNote(RemoteNoteSnapshot snapshot) async {
    final result = await _client.pushSnapshot(
      peerId: peerId,
      snapshot: remoteSnapshotToJson(snapshot),
    );
    if (result.lanFallback) {
      throw StateError('sidecar wire push delegated to LAN fallback');
    }
    return NoteApplyResult.applied;
  }

  @override
  Future<List<int>?> fetchAttachment(String noteId, String fileName) =>
      _client.pullAttachment(
        noteId: noteId,
        name: fileName,
        peerId: peerId,
      );

  @override
  Future<void> pushAttachment(
    String noteId,
    AttachmentMeta meta,
    List<int> bytes,
  ) async {
    final ok = await _client.pushAttachment(
      noteId: noteId,
      name: meta.name,
      bytes: bytes,
      peerId: peerId,
    );
    if (!ok) {
      throw StateError('sidecar wire attachment push rejected');
    }
  }
}
