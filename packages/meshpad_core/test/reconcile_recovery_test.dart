import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_recover_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('missing Drift index recovers via reconcileFromFilesystem', () async {
    final db1 = createMeshPadDatabase(tempDir.path);
    final repo1 = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'device-a',
      database: db1,
    );
    final note = await repo1.createNote(title: 'FS truth', markdown: 'body');
    expect((await repo1.listNotes()).length, 1);

    final dbPath = p.join(tempDir.path, 'index', 'meshpad.db');
    expect(await File(dbPath).exists(), isTrue);
    await db1.close();
    await File(dbPath).delete();

    final db2 = createMeshPadDatabase(tempDir.path);
    try {
      final repo2 = createNoteRepository(
        dataDir: tempDir.path,
        defaultAuthor: 'device-a',
        database: db2,
      );
      expect(await repo2.listNotes(), isEmpty);

      final count = await repo2.reconcileFromFilesystem();
      expect(count, 1);
      final restored = await repo2.getNote(note.id);
      expect(restored?.title, 'FS truth');
      expect(restored?.markdown, 'body');
    } finally {
      await db2.close();
    }
  });
}
