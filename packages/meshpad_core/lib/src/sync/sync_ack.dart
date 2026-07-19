import '../models/sync_event.dart';
import '../repositories/note_repository.dart';
import 'remote_sync_gateway.dart';
import 'sync_engine.dart';
import '../storage/attachment_storage.dart';

/// True when [remote] has [noteId] with meta at least as new as local and all attachments match.
Future<bool> isNoteFullySyncedOnRemote({
  required NoteRepository localNotes,
  required RemoteSyncGateway remote,
  required String noteId,
}) async {
  final localMeta = await localNotes.readNoteMeta(noteId);
  final remoteSnapshot = await remote.fetchNote(noteId);

  // Orphan outbox (folder gone before purge tombstones): clear when peer
  // also lacks the note or already has a purge tombstone.
  if (localMeta == null) {
    if (remoteSnapshot == null) return true;
    return remoteSnapshot.meta.purged;
  }

  if (localMeta.purged) {
    if (remoteSnapshot == null) return true;
    return remoteSnapshot.meta.purged;
  }

  final local = await localNotes.getNote(noteId);
  if (local == null) return false;

  final localNoteMeta = local.toMeta();
  if (remoteSnapshot == null) return false;

  final remoteMeta = remoteSnapshot.meta;
  if (remoteMeta.updatedAt.isBefore(localNoteMeta.updatedAt)) return false;
  if (remoteMeta.deleted != localNoteMeta.deleted) return false;

  if (localNoteMeta.deleted) return true;

  for (final attachment in localMeta.attachments) {
    final hasMeta =
        remoteMeta.attachments.any((a) => a.name == attachment.name);
    if (!hasMeta) return false;

    final bytes = await remote.fetchAttachment(noteId, attachment.name);
    if (bytes == null || !attachmentBytesMatch(bytes, attachment)) {
      return false;
    }
  }

  return true;
}

extension SyncEngineRemoteAck on SyncEngine {
  /// Clears outbox rows only for notes fully present on [remote] (meta + attachments).
  Future<int> acknowledgeSyncedWithRemote(RemoteSyncGateway remote) async {
    final outbox = await notes.listOutbox();
    var cleared = 0;

    for (final entry in outbox) {
      if (entry.entityType != SyncEvent.entityNote) continue;
      if (!await isNoteFullySyncedOnRemote(
        localNotes: notes,
        remote: remote,
        noteId: entry.entityId,
      )) {
        continue;
      }
      await notes.removeOutboxEntry(entry.id);
      cleared++;
    }

    return cleared;
  }

  Future<void> tryAckOutboxForRemoteNote(
    RemoteSyncGateway remote,
    String noteId,
  ) async {
    if (!await isNoteFullySyncedOnRemote(
      localNotes: notes,
      remote: remote,
      noteId: noteId,
    )) {
      return;
    }

    final outbox = await notes.listOutbox();
    for (final entry in outbox) {
      if (entry.entityType != SyncEvent.entityNote) continue;
      if (entry.entityId != noteId) continue;
      await notes.removeOutboxEntry(entry.id);
    }
  }
}
