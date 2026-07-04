import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('NoteFsSignatures.matches ignores sub-second drift', () {
    final cached = NoteFsSignatures(
      metaModifiedAt: DateTime.utc(2026, 1, 1, 12, 0, 0, 100),
      markdownModifiedAt: DateTime.utc(2026, 1, 1, 12, 0, 0, 100),
    );
    final onDisk = NoteFsSignatures(
      metaModifiedAt: DateTime.utc(2026, 1, 1, 12, 0, 0, 900),
      markdownModifiedAt: DateTime.utc(2026, 1, 1, 12, 0, 0, 500),
    );

    expect(cached.matches(onDisk), isTrue);
  });

  test('NoteFsSignatures.matches detects second-level changes', () {
    final cached = NoteFsSignatures(
      metaModifiedAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
      markdownModifiedAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
    );
    final onDisk = NoteFsSignatures(
      metaModifiedAt: DateTime.utc(2026, 1, 1, 12, 0, 1),
      markdownModifiedAt: DateTime.utc(2026, 1, 1, 12, 0, 0),
    );

    expect(cached.matches(onDisk), isFalse);
  });

  late Directory tempDir;
  late MeshPadDatabase db;
  late NoteRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_incr_');
    db = createMeshPadDatabase(tempDir.path);
    repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'device-a',
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reconcile skips notes already indexed with matching mtimes', () async {
    await repo.createNote(title: 'Hello', markdown: 'body');

    expect(await repo.reconcileFromFilesystem(), 0);
    expect(await repo.reconcileFromFilesystem(), 0);
  });

  test('reconcile re-indexes when meta.json mtime changes', () async {
    final note = await repo.createNote(title: 'Hello', markdown: 'body');
    expect(await repo.reconcileFromFilesystem(), 0);

    final metaPath = p.join(tempDir.path, 'notes', note.id, 'meta.json');
    final metaFile = File(metaPath);
    await metaFile.writeAsString(
      await metaFile.readAsString(),
      flush: true,
    );
    await metaFile.setLastModified(
      DateTime.now().toUtc().add(const Duration(seconds: 5)),
    );

    expect(await repo.reconcileFromFilesystem(), 1);
  });

  test('reconcile removes Drift rows for deleted note folders', () async {
    final note = await repo.createNote(title: 'Gone', markdown: 'x');
    expect((await repo.listNotes()).length, 1);

    final noteDir = Directory(p.join(tempDir.path, 'notes', note.id));
    await noteDir.delete(recursive: true);

    expect(await repo.reconcileFromFilesystem(), 0);
    expect(await repo.listNotes(), isEmpty);
  });
}
