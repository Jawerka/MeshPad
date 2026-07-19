import 'dart:developer' as developer;

import '../models/note_head.dart';
import '../models/note_meta.dart';
import 'catalog_delta.dart';
import 'remote_note_snapshot.dart';
import 'sync_ack.dart';
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

/// Result of pushing local notes to a remote peer.
class PushToRemoteResult {
  const PushToRemoteResult({
    required this.pushed,
    required this.failedNoteIds,
  });

  final int pushed;
  final List<String> failedNoteIds;
}

extension SyncEngineRemote on SyncEngine {
  Future<SyncSessionResult> syncWithRemote(RemoteSyncGateway remote) async {
    final pulled = await pullFromRemote(remote);
    final pushResult = await pushToRemote(remote);
    final acknowledged = await acknowledgeSyncedWithRemote(remote);
    return SyncSessionResult(
      pulled: pulled,
      receivedByPeer: pushResult.pushed,
      acknowledged: acknowledged,
      failedPushNoteIds: pushResult.failedNoteIds,
    );
  }

  Future<int> pullFromRemote(RemoteSyncGateway remote) async {
    final stats = await pullFromRemoteWithStats(remote);
    return stats.applied;
  }

  /// Delta pull stats (catalog compare without redundant note GETs).
  Future<CatalogPullStats> pullFromRemoteWithStats(
    RemoteSyncGateway remote,
  ) async {
    final remoteHeads = await remote.fetchCatalog();
    final localHeads = await notes.catalogHeads();
    final localById = {for (final head in localHeads) head.id: head};
    var applied = 0;
    var bodiesFetched = 0;
    var bodiesSkipped = 0;

    for (final head in remoteHeads) {
      final localHead = localById[head.id];
      if (!noteHeadNeedsRemotePull(localHead: localHead, remoteHead: head)) {
        bodiesSkipped++;
        final note = await notes.getNote(head.id);
        if (note != null) {
          await syncAttachmentsFrom(remote, note.toMeta());
        }
        continue;
      }

      bodiesFetched++;
      final snapshot = await remote.fetchNote(head.id);
      if (snapshot == null) continue;

      final result = await applyRemote(snapshot);
      if (result == NoteApplyResult.applied ||
          result == NoteApplyResult.conflictCopyCreated) {
        applied++;
      }
      if (!snapshot.meta.purged) {
        await syncAttachmentsFrom(remote, snapshot.meta);
      }
    }

    return CatalogPullStats(
      catalogSize: remoteHeads.length,
      bodiesFetched: bodiesFetched,
      bodiesSkipped: bodiesSkipped,
      applied: applied,
    );
  }

  Future<PushToRemoteResult> pushToRemote(RemoteSyncGateway remote) async {
    final remoteHeads = await remote.fetchCatalog();
    final byId = {for (final head in remoteHeads) head.id: head};
    var pushed = 0;
    final failedNoteIds = <String>[];

    for (final head in await localCatalog()) {
      final remoteHead = byId[head.id];
      final needsPush = remoteHead == null ||
          head.updatedAt.isAfter(remoteHead.updatedAt) ||
          (head.updatedAt == remoteHead.updatedAt &&
              (head.deleted != remoteHead.deleted ||
                  head.purged != remoteHead.purged));
      if (!needsPush) continue;

      final snapshot = await exportNote(head.id);
      if (snapshot == null) continue;

      try {
        final result = await remote.pushNote(snapshot);
        if (result == NoteApplyResult.applied) pushed++;
        if (!snapshot.meta.purged) {
          await syncAttachmentsTo(remote, snapshot.meta);
        }
        if (!await isNoteFullySyncedOnRemote(
          localNotes: notes,
          remote: remote,
          noteId: head.id,
        )) {
          failedNoteIds.add(head.id);
        } else {
          await tryAckOutboxForRemoteNote(remote, head.id);
        }
      } on Object catch (e) {
        developer.log(
          'push note ${head.id} failed: $e',
          name: 'meshpad.sync',
        );
        failedNoteIds.add(head.id);
      }
    }

    return PushToRemoteResult(pushed: pushed, failedNoteIds: failedNoteIds);
  }

  Future<void> syncAttachmentsFrom(
    RemoteSyncGateway remote,
    NoteMeta meta,
  ) async {
    for (final attachment in meta.attachments) {
      try {
        if (await notes.attachmentMatches(meta.id, attachment)) continue;

        final bytes = await remote.fetchAttachment(meta.id, attachment.name);
        if (bytes == null) continue;

        await notes.storeRemoteAttachment(meta.id, attachment, bytes);
      } on Object catch (e) {
        developer.log(
          'pull attachment ${meta.id}/${attachment.name} failed: $e',
          name: 'meshpad.sync',
        );
      }
    }
  }

  Future<void> syncAttachmentsTo(
    RemoteSyncGateway remote,
    NoteMeta meta,
  ) async {
    for (final attachment in meta.attachments) {
      try {
        final bytes = await notes.readAttachmentBytes(meta.id, attachment.name);
        if (bytes == null) continue;

        await remote.pushAttachment(meta.id, attachment, bytes);
      } on Object catch (e) {
        developer.log(
          'push attachment ${meta.id}/${attachment.name} failed: $e',
          name: 'meshpad.sync',
        );
      }
    }
  }
}

/// JSON helpers for LAN / libp2p wire format.
List<NoteHead> noteHeadsFromJsonList(List<dynamic> list) => [
      for (final item in list) NoteHead.fromJson(item as Map<String, dynamic>),
    ];

/// Safe catalog decode for fuzzing and tolerant gateways.
List<NoteHead>? tryParseCatalogJson(Object? decoded) {
  if (decoded is! List) return null;
  try {
    return noteHeadsFromJsonList(decoded);
  } on Object {
    return null;
  }
}

/// Safe snapshot decode; returns null on invalid shape.
RemoteNoteSnapshot? tryParseRemoteSnapshotJson(Object? decoded) {
  if (decoded is! Map<String, dynamic>) return null;
  try {
    return remoteSnapshotFromJson(decoded);
  } on Object {
    return null;
  }
}

Map<String, dynamic> remoteSnapshotToJson(RemoteNoteSnapshot snapshot) => {
      'meta': snapshot.meta.toJson(),
      'markdown': snapshot.markdown,
    };

RemoteNoteSnapshot remoteSnapshotFromJson(Map<String, dynamic> json) =>
    RemoteNoteSnapshot(
      meta: NoteMeta.fromJson(json['meta'] as Map<String, dynamic>),
      markdown: json['markdown'] as String? ?? '',
    );
