import '../models/note_head.dart';
import '../models/note_meta.dart';
import 'remote_note_snapshot.dart';
import 'sync_engine.dart';

/// Remote peer that supports pull (catalog + note) and push (apply snapshot).
abstract class RemoteSyncGateway implements SyncPeer {
  Future<NoteApplyResult> pushNote(RemoteNoteSnapshot snapshot);

  Future<List<int>?> fetchAttachment(String noteId, String fileName);

  Future<void> pushAttachment(
    String noteId,
    AttachmentMeta meta,
    List<int> bytes,
  );
}

extension SyncEngineRemote on SyncEngine {
  Future<SyncSessionResult> syncWithRemote(RemoteSyncGateway remote) async {
    final pulled = await pullFromRemote(remote);
    final pushed = await pushToRemote(remote);
    final acknowledged = await acknowledgeSyncedWith(remote);
    return SyncSessionResult(
      pulled: pulled,
      receivedByPeer: pushed,
      acknowledged: acknowledged,
    );
  }

  Future<int> pullFromRemote(RemoteSyncGateway remote) async {
    final heads = await remote.fetchCatalog();
    var applied = 0;

    for (final head in heads) {
      final local = await notes.getNote(head.id);
      final localUpdated =
          local?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

      final needsUpdate = local == null ||
          head.updatedAt.isAfter(localUpdated) ||
          (head.updatedAt == localUpdated && head.deleted != local.deleted);

      if (!needsUpdate) {
        final note = await notes.getNote(head.id);
        if (note != null) {
          await syncAttachmentsFrom(remote, note.toMeta());
        }
        continue;
      }

      final snapshot = await remote.fetchNote(head.id);
      if (snapshot == null) continue;

      final result = await applyRemote(snapshot);
      if (result == NoteApplyResult.applied) applied++;
      await syncAttachmentsFrom(remote, snapshot.meta);
    }

    return applied;
  }

  Future<int> pushToRemote(RemoteSyncGateway remote) async {
    final remoteHeads = await remote.fetchCatalog();
    final byId = {for (final head in remoteHeads) head.id: head};
    var pushed = 0;

    for (final head in await localCatalog()) {
      final remoteHead = byId[head.id];
      final needsPush = remoteHead == null ||
          head.updatedAt.isAfter(remoteHead.updatedAt) ||
          (head.updatedAt == remoteHead.updatedAt &&
              head.deleted != remoteHead.deleted);
      if (!needsPush) continue;

      final snapshot = await exportNote(head.id);
      if (snapshot == null) continue;

      final result = await remote.pushNote(snapshot);
      if (result == NoteApplyResult.applied) pushed++;
      await syncAttachmentsTo(remote, snapshot.meta);
    }

    return pushed;
  }

  Future<void> syncAttachmentsFrom(
    RemoteSyncGateway remote,
    NoteMeta meta,
  ) async {
    for (final attachment in meta.attachments) {
      if (await notes.attachmentMatches(meta.id, attachment)) continue;

      final bytes = await remote.fetchAttachment(meta.id, attachment.name);
      if (bytes == null) continue;

      await notes.storeRemoteAttachment(meta.id, attachment, bytes);
    }
  }

  Future<void> syncAttachmentsTo(
    RemoteSyncGateway remote,
    NoteMeta meta,
  ) async {
    for (final attachment in meta.attachments) {
      final bytes = await notes.readAttachmentBytes(meta.id, attachment.name);
      if (bytes == null) continue;

      await remote.pushAttachment(meta.id, attachment, bytes);
    }
  }
}

/// JSON helpers for LAN / libp2p wire format.
List<NoteHead> noteHeadsFromJsonList(List<dynamic> list) => [
      for (final item in list) NoteHead.fromJson(item as Map<String, dynamic>),
    ];

Map<String, dynamic> remoteSnapshotToJson(RemoteNoteSnapshot snapshot) => {
      'meta': snapshot.meta.toJson(),
      'markdown': snapshot.markdown,
    };

RemoteNoteSnapshot remoteSnapshotFromJson(Map<String, dynamic> json) =>
    RemoteNoteSnapshot(
      meta: NoteMeta.fromJson(json['meta'] as Map<String, dynamic>),
      markdown: json['markdown'] as String? ?? '',
    );
