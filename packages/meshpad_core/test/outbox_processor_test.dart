import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('statusMap marks pending and error by retry count', () {
    final processor = OutboxProcessor(maxRetries: 3);
    final map = processor.statusMap(
      [
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
      ],
      noteAuthors: const {'a': '', 'b': ''},
      localAuthorLabels: const {'', 'Android'},
    );

    expect(map['a'], NoteSyncStatus.pending);
    expect(map['b'], NoteSyncStatus.error);
  });

  test('statusMap ignores outbox for remote-authored notes', () {
    final processor = OutboxProcessor(maxRetries: 3);
    final map = processor.statusMap(
      [
        SyncEvent(
          id: 1,
          entityType: SyncEvent.entityNote,
          entityId: 'remote',
          operation: SyncEvent.opUpsert,
          createdAt: DateTime.utc(2026, 1, 1),
          retryCount: 5,
        ),
      ],
      noteAuthors: const {'remote': 'Windows'},
      localAuthorLabels: const {'', 'Android'},
    );

    expect(map.containsKey('remote'), isFalse);
  });
}
