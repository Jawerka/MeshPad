/// UI-facing sync state for a note card (see docs/ARCHITECTURE.md).
enum NoteSyncStatus {
  /// Saved locally, not in the outbound sync queue.
  synced,

  /// Waiting to be pushed to a trusted peer.
  pending,

  /// Outbox entry exceeded retry limit.
  error,
}
