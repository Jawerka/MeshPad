import 'dart:isolate';

import '../database/database.dart';
import 'note_repository.dart';

/// PLAN §11.5.2 — run full reconcile off the UI isolate when the library is large.
const int reconcileIsolateNoteThreshold = 500;

/// Runs [reconcileFromFilesystem] in a fresh isolate with its own Drift connection.
Future<int> runReconcileInIsolate({
  required String dataDir,
  required String defaultAuthor,
  int? thumbCacheMaxMb,
}) {
  return Isolate.run(() async {
    final db = createMeshPadDatabase(dataDir);
    try {
      final repo = createNoteRepository(
        dataDir: dataDir,
        defaultAuthor: defaultAuthor,
        database: db,
      );
      return await repo.reconcileFromFilesystem(
        thumbCacheMaxMb: thumbCacheMaxMb,
      );
    } finally {
      await db.close();
    }
  });
}
