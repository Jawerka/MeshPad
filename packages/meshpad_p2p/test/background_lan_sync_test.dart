import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_bg_sync_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('runBackgroundSyncPass skips LAN sync without trusted peers', () async {
    final db = createMeshPadDatabase(tempDir.path);
    addTearDown(db.close);

    final repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test',
      database: db,
    );
    await repo.createNote(markdown: 'local note');
    await db.close();

    final result = await runBackgroundSyncPass(dataDir: tempDir.path);

    expect(result.indexedNotes, greaterThanOrEqualTo(1));
    expect(result.trustedDeviceCount, 0);
    expect(result.lanSyncStatus, LanSyncRunStatus.noPeers);
  });

  test('runBackgroundSyncPass purges expired trash', () async {
    final db = createMeshPadDatabase(tempDir.path);
    addTearDown(db.close);

    final repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test',
      database: db,
    );
    final note = await repo.createNote(markdown: 'old trash');
    await repo.deleteNote(note.id);

    final metaPath = p.join(tempDir.path, 'notes', note.id, 'meta.json');
    final raw =
        jsonDecode(await File(metaPath).readAsString()) as Map<String, dynamic>;
    raw['deleted_at'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 8))
        .toIso8601String();
    await File(metaPath).writeAsString(jsonEncode(raw));
    await db.close();

    final result = await runBackgroundSyncPass(dataDir: tempDir.path);

    expect(result.purgedTrash, 1);

    final verifyDb = createMeshPadDatabase(tempDir.path);
    addTearDown(verifyDb.close);
    final verifyRepo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test',
      database: verifyDb,
    );
    expect(await verifyRepo.listTrash(), isEmpty);
  });
}
