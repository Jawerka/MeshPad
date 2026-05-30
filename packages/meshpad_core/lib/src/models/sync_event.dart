/// Pending sync operation stored in [SyncOutbox].
class SyncEvent {
  const SyncEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.createdAt,
    this.payload,
    this.retryCount = 0,
  });

  final int id;
  final String entityType;
  final String entityId;
  final String operation;
  final String? payload;
  final DateTime createdAt;
  final int retryCount;

  static const entityNote = 'note';
  static const opUpsert = 'upsert';
  static const opDelete = 'delete';
  static const opPurge = 'purge';
}
