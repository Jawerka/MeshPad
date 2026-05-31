import '../models/sync_event.dart';
import '../repositories/note_repository.dart';
import 'note_sync_status.dart';

/// Processes [SyncOutbox] retries and derives per-note sync status.
class OutboxProcessor {
  OutboxProcessor({this.maxRetries = 5});

  final int maxRetries;

  Map<String, NoteSyncStatus> statusMap(
    List<SyncEvent> outbox, {
    Map<String, String>? noteAuthors,
    Set<String>? localAuthorLabels,
  }) {
    final map = <String, NoteSyncStatus>{};
    final localAuthors = localAuthorLabels ?? const {'', 'Это устройство'};
    for (final entry in outbox) {
      if (entry.entityType != SyncEvent.entityNote) continue;
      final author = noteAuthors?[entry.entityId]?.trim() ?? '';
      if (!localAuthors.contains(author)) continue;
      map[entry.entityId] = entry.retryCount >= maxRetries
          ? NoteSyncStatus.error
          : NoteSyncStatus.pending;
    }
    return map;
  }

  Future<int> recordSyncFailure(NoteRepository repo) async {
    final entries = await repo.listOutbox();
    var bumped = 0;
    for (final entry in entries) {
      await repo.incrementOutboxRetry(entry.id);
      bumped++;
    }
    return bumped;
  }

  Future<int> failedCount(NoteRepository repo) async {
    final entries = await repo.listOutbox();
    return entries.where((e) => e.retryCount >= maxRetries).length;
  }
}
