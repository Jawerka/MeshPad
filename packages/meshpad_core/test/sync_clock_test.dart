import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('inspectRemoteNoteTimestamp reports future updated_at', () {
    final messages = <String>[];
    SyncClockMonitor.onAnomaly = messages.add;

    inspectRemoteNoteTimestamp(
      noteId: 'n1',
      remoteUpdatedAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    );

    expect(messages, isNotEmpty);
    expect(messages.first, contains('future'));

    SyncClockMonitor.onAnomaly = null;
  });

  test('inspectRemoteNoteTimestamp reports large skew', () {
    final messages = <String>[];
    SyncClockMonitor.onAnomaly = messages.add;

    final local = DateTime.utc(2026, 1, 1);
    inspectRemoteNoteTimestamp(
      noteId: 'n2',
      remoteUpdatedAt: local.add(const Duration(days: 2)),
      localUpdatedAt: local,
    );

    expect(messages.any((m) => m.contains('skew')), isTrue);
    SyncClockMonitor.onAnomaly = null;
  });
}
