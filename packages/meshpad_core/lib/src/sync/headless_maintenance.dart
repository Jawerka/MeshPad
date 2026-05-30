import '../storage/device_identity_store.dart';
import '../storage/meshpad_paths.dart';
import '../repositories/note_repository.dart';
import '../database/database.dart';

/// Result of a headless maintenance pass (Android WorkManager, Linux server).
class HeadlessMaintenanceResult {
  const HeadlessMaintenanceResult({
    required this.indexedNotes,
    required this.trustedDeviceCount,
  });

  final int indexedNotes;
  final int trustedDeviceCount;
}

/// Runs FS→DB reconcile and trash purge without Flutter UI.
Future<HeadlessMaintenanceResult> runHeadlessMaintenance({
  required String dataDir,
  String defaultAuthor = 'Это устройство',
}) async {
  final db = createMeshPadDatabase(dataDir);
  try {
    final repo = createNoteRepository(
      dataDir: dataDir,
      defaultAuthor: defaultAuthor,
      database: db,
    );
    final indexed = await repo.reconcileFromFilesystem();
    final store = DeviceIdentityStore(paths: MeshPadPaths(dataDir));
    final trusted = await store.listTrustedDevices();
    return HeadlessMaintenanceResult(
      indexedNotes: indexed,
      trustedDeviceCount: trusted.length,
    );
  } finally {
    await db.close();
  }
}
