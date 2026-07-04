import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/providers/sync_providers.dart';

void main() {
  test('SyncRunResult.failed carries user message', () {
    const result = SyncRunResult(
      SyncRunStatus.failed,
      message: 'LAN transport недоступен',
    );
    expect(result.status, SyncRunStatus.failed);
    expect(result.message, isNotNull);
  });

  test('SyncRunStatus values cover pipeline outcomes', () {
    expect(
        SyncRunStatus.values,
        containsAll([
          SyncRunStatus.noPeers,
          SyncRunStatus.completed,
          SyncRunStatus.partial,
          SyncRunStatus.failed,
        ]));
  });
}
