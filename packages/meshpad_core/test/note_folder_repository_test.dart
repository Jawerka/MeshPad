import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late NoteFolderRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_test_');
    repo = NoteFolderRepository(notesRoot: '${tempDir.path}/notes');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('write and read note folder', () async {
    final id = '550e8400-e29b-41d4-a716-446655440000';
    final path = '${tempDir.path}/notes/$id';
    final meta = NoteMeta(
      schemaVersion: 1,
      id: id,
      title: 'Заметка',
      createdAt: DateTime.utc(2026, 5, 29),
      updatedAt: DateTime.utc(2026, 5, 29),
      author: 'test-device',
    );

    await repo.write(
      NoteFolder(path: path, meta: meta, markdown: '# Привет\n'),
    );

    final loaded = await repo.read(id);
    expect(loaded, isNotNull);
    expect(loaded!.meta.title, 'Заметка');
    expect(loaded.markdown, contains('Привет'));
  });
}
