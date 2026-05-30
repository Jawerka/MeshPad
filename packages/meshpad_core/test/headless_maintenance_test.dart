import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_headless_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('runHeadlessMaintenance indexes notes from filesystem', () async {
    final db = createMeshPadDatabase(tempDir.path);
    final repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test',
      database: db,
    );
    await repo.createNote(title: 't', markdown: 'hello headless');
    await db.close();

    final result = await runHeadlessMaintenance(dataDir: tempDir.path);

    expect(result.indexedNotes, 1);
    expect(result.trustedDeviceCount, 0);
  });
}
