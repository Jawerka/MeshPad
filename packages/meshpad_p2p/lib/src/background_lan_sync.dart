import 'package:meshpad_core/meshpad_core.dart';

import 'lan/lan_sync_coordinator.dart';
import 'lan/lan_sync_transport.dart';
import 'meshpad_log.dart';

/// Result of a headless background sync pass (Android WorkManager, PLAN §12 C.4).
class BackgroundSyncPassResult {
  const BackgroundSyncPassResult({
    required this.indexedNotes,
    required this.purgedTrash,
    required this.trustedDeviceCount,
    required this.lanSyncStatus,
    this.lanSyncNoteCount = 0,
    this.lanSyncMessage,
  });

  final int indexedNotes;
  final int purgedTrash;
  final int trustedDeviceCount;
  final LanSyncRunStatus lanSyncStatus;
  final int lanSyncNoteCount;
  final String? lanSyncMessage;
}

/// Maintenance + optional LAN sync without Flutter UI.
///
/// Skips LAN sync when there are no trusted peers. Respects OS limits: caller
/// should only invoke on Android with [NetworkType.connected] (WorkManager).
Future<BackgroundSyncPassResult> runBackgroundSyncPass({
  required String dataDir,
}) async {
  final db = createMeshPadDatabase(dataDir);
  try {
    final paths = MeshPadPaths(dataDir);
    final deviceStore = DeviceIdentityStore(paths: paths);
    final identity = await deviceStore.loadOrCreateIdentity();
    final repo = createNoteRepository(
      dataDir: dataDir,
      defaultAuthor: identity.displayName,
      database: db,
    );

    final reconcileStopwatch = Stopwatch()..start();
    final indexed = await repo.reconcileFromFilesystem();
    reconcileStopwatch.stop();
    MeshPadLog.metric(
      'reconcile_duration_ms',
      '${reconcileStopwatch.elapsedMilliseconds}',
    );
    MeshPadLog.metric('reconcile_notes', '$indexed');
    final purged = await repo.purgeExpiredTrash();
    final trusted = await deviceStore.listTrustedDevices();

    MeshPadLog.sync(
      'background pass indexed=$indexed purged=$purged trusted=${trusted.length}',
    );

    if (trusted.isEmpty) {
      return BackgroundSyncPassResult(
        indexedNotes: indexed,
        purgedTrash: purged,
        trustedDeviceCount: 0,
        lanSyncStatus: LanSyncRunStatus.noPeers,
        lanSyncMessage: 'Нет доверенных устройств',
      );
    }

    final engine = SyncEngine(notes: repo, identity: identity);
    final transport = LanSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      getDeviceStore: () async => deviceStore,
    );
    final coordinator = LanSyncCoordinator(deviceStore: deviceStore);

    await transport.start();
    try {
      final lanResult = await coordinator.syncTrustedPeers(
        transport: transport,
        repository: repo,
        localPeerId: identity.peerId,
        propagateCascade: false,
      );
      MeshPadLog.sync(
        'background LAN sync ${lanResult.status.name} notes=${lanResult.noteCount}',
      );
      return BackgroundSyncPassResult(
        indexedNotes: indexed,
        purgedTrash: purged,
        trustedDeviceCount: trusted.length,
        lanSyncStatus: lanResult.status,
        lanSyncNoteCount: lanResult.noteCount,
        lanSyncMessage: lanResult.message,
      );
    } finally {
      await transport.stop();
    }
  } finally {
    await db.close();
  }
}
