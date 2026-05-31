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
  final local = await localNotes.getNote(noteId);
  if (local == null) return false;

  final localMeta = local.toMeta();
  final remoteSnapshot = await remote.fetchNote(noteId);
  if (remoteSnapshot == null) return false;

  final remoteMeta = remoteSnapshot.meta;
  if (remoteMeta.updatedAt.isBefore(localMeta.updatedAt)) return false;
  if (remoteMeta.deleted != localMeta.deleted) return false;

  if (localMeta.deleted) return true;

  for (final attachment in localMeta.attachments) {
    final hasMeta = remoteMeta.attachments.any((a) => a.name == attachment.name);
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
