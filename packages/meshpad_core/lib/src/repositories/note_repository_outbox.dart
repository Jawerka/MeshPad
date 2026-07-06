part of 'note_repository.dart';

mixin _NoteRepositoryOutbox on _NoteRepositoryHost, _NoteRepositoryCrud {
  Future<int> pendingOutboxCount() => _db.pendingOutboxCount();

  Future<Set<String>> pendingOutboxNoteIds() => _db.pendingOutboxNoteIds();

  Future<List<SyncEvent>> listOutbox() async {
    final rows = await _db.listOutboxEntries();
    return rows
        .map(
          (row) => SyncEvent(
            id: row.id,
            entityType: row.entityType,
            entityId: row.entityId,
            operation: row.operation,
            payload: row.payload,
            createdAt: row.createdAt,
            retryCount: row.retryCount,
          ),
        )
        .toList();
  }

  Future<void> removeOutboxEntry(int id) => _db.removeOutboxEntry(id);

  Future<void> incrementOutboxRetry(int id) => _db.incrementOutboxRetry(id);

  /// Removes outbox rows for notes authored on other devices (legacy bug).
  Future<int> purgeMisfiledRemoteOutbox({
    required Set<String> localAuthorLabels,
  }) async {
    final outbox = await listOutbox();
    var removed = 0;
    for (final entry in outbox) {
      if (entry.entityType != SyncEvent.entityNote) continue;
      final note = await getNote(entry.entityId);
      if (note == null) continue;
      if (!localAuthorLabels.contains(note.author.trim())) {
        await removeOutboxEntry(entry.id);
        removed++;
      }
    }
    return removed;
  }

  /// Drops outbox rows that exceeded retry limit (legacy false errors).
  Future<int> purgeExhaustedOutboxEntries({required int maxRetries}) async {
    final outbox = await listOutbox();
    var removed = 0;
    for (final entry in outbox) {
      if (entry.retryCount >= maxRetries) {
        await removeOutboxEntry(entry.id);
        removed++;
      }
    }
    return removed;
  }
}
