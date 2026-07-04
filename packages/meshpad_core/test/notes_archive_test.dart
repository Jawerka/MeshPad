import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<void> _writeNote(
  MeshPadPaths paths, {
  required String id,
  required String title,
  required DateTime updatedAt,
  required String body,
  String author = 'local',
}) async {
  final dir = Directory(paths.noteDir(id));
  await dir.create(recursive: true);
  final meta = NoteMeta(
    schemaVersion: 1,
    id: id,
    title: title,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    author: author,
  );
  await File(p.join(dir.path, 'meta.json'))
      .writeAsString(jsonEncode(meta.toJson()));
  await File(p.join(dir.path, 'body.md')).writeAsString(body);
}

void main() {
  late Directory tempDir;
  late MeshPadPaths paths;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_archive_');
    paths = MeshPadPaths(tempDir.path);
    await Directory(paths.notesRoot).create(recursive: true);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('export and import round-trip adds new notes', () async {
    const noteId = '11111111-1111-1111-1111-111111111111';
    await _writeNote(
      paths,
      id: noteId,
      title: 'Export me',
      updatedAt: DateTime.utc(2025, 1, 1),
      body: '# Hi',
    );

    final zipPath = p.join(tempDir.path, 'export.zip');
    final count =
        await NotesArchive.exportToFile(paths: paths, zipPath: zipPath);
    expect(count, 1);
    expect(await File(zipPath).exists(), isTrue);

    await Directory(paths.noteDir(noteId)).delete(recursive: true);
    final result = await NotesArchive.importFromFile(
      paths: paths,
      zipPath: zipPath,
    );
    expect(result.imported, 1);
    expect(
      await File(p.join(paths.noteDir(noteId), 'body.md')).exists(),
      isTrue,
    );
  });

  test('import skips when local note is newer', () async {
    const noteId = '22222222-2222-2222-2222-222222222222';
    await _writeNote(
      paths,
      id: noteId,
      title: 'Local',
      updatedAt: DateTime.utc(2025, 6, 1),
      body: 'local wins',
    );

    final src = MeshPadPaths(p.join(tempDir.path, 'src'));
    await Directory(src.notesRoot).create(recursive: true);
    await _writeNote(
      src,
      id: noteId,
      title: 'Remote',
      updatedAt: DateTime.utc(2025, 1, 1),
      body: 'remote loses',
      author: 'remote',
    );

    final zipPath = p.join(tempDir.path, 'older.zip');
    await NotesArchive.exportToFile(paths: src, zipPath: zipPath);

    final result = await NotesArchive.importFromFile(
      paths: paths,
      zipPath: zipPath,
    );
    expect(result.skipped, 1);
    expect(
      await File(p.join(paths.noteDir(noteId), 'body.md')).readAsString(),
      'local wins',
    );
  });
}
