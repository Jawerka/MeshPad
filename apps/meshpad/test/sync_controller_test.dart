import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/providers/sync_providers.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

void main() {
  test('SyncRunStatus includes partial for mixed peer results', () {
    expect(SyncRunStatus.values, contains(SyncRunStatus.partial));
  });

  test('LanSyncRunStatus partial maps to app partial status', () {
    const lanResult = LanSyncRunResult(
      LanSyncRunStatus.partial,
      noteCount: 2,
      message: 'one peer failed',
    );
    final appStatus = switch (lanResult.status) {
      LanSyncRunStatus.noPeers => SyncRunStatus.noPeers,
      LanSyncRunStatus.completed => SyncRunStatus.completed,
      LanSyncRunStatus.partial => SyncRunStatus.partial,
      LanSyncRunStatus.failed => SyncRunStatus.failed,
    };
    expect(appStatus, SyncRunStatus.partial);
    expect(lanResult.noteCount, 2);
  });

  test('sync controller mutex flag tracks busy state', () {
    resetSyncControllerBusyForTest();
    expect(isSyncControllerBusy, isFalse);
    setSyncControllerBusyForTest(true);
    expect(isSyncControllerBusy, isTrue);
    resetSyncControllerBusyForTest();
    expect(isSyncControllerBusy, isFalse);
  });
}
