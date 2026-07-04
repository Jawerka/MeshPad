import 'package:test/test.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_server/hub/hub_sync_tracker.dart';

void main() {
  test('tracker records completed sync message', () {
    final tracker = HubSyncTracker();
    tracker.recordResult(
      const LanSyncRunResult(LanSyncRunStatus.completed, noteCount: 3),
    );
    expect(tracker.events.first.message, 'Успешно — 3 заметок');
    expect(tracker.events.first.kind, HubSyncEventKind.completed);
  });
}
