import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('statusMap marks pending and error by retry count', () {
    final processor = OutboxProcessor(maxRetries: 3);
    final map = processor.statusMap([
      SyncEvent(
        id: 1,
        entityType: SyncEvent.entityNote,
        entityId: 'a',
        operation: SyncEvent.opUpsert,
        createdAt: DateTime.utc(2026, 1, 1),
        retryCount: 0,
      ),
      SyncEvent(
        id: 2,
        entityType: SyncEvent.entityNote,
        entityId: 'b',
        operation: SyncEvent.opUpsert,
        createdAt: DateTime.utc(2026, 1, 1),
        retryCount: 3,
      ),
    ]);

    expect(map['a'], NoteSyncStatus.pending);
    expect(map['b'], NoteSyncStatus.error);
  });
}
