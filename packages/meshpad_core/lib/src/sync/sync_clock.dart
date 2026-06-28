/// Clock skew detection for sync (PLAN §11.2.3).
abstract final class SyncClockMonitor {
  static void Function(String message)? onAnomaly;
}

void inspectRemoteNoteTimestamp({
  required String noteId,
  required DateTime remoteUpdatedAt,
  DateTime? localUpdatedAt,
}) {
  final log = SyncClockMonitor.onAnomaly;
  if (log == null) return;

  final now = DateTime.now().toUtc();
  final remote = remoteUpdatedAt.toUtc();

  if (remote.isAfter(now.add(const Duration(minutes: 2)))) {
    log('note $noteId: remote updated_at in future ($remote, now=$now)');
  }

  if (localUpdatedAt != null) {
    final local = localUpdatedAt.toUtc();
    final delta = remote.difference(local).abs();
    if (delta > const Duration(hours: 24)) {
      log(
        'note $noteId: updated_at skew ${delta.inHours}h '
        '(local=$local remote=$remote)',
      );
    }
  }
}
