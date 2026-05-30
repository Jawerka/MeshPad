import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late MeshPadDatabase db;
  late NoteRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_attach_');
    db = MeshPadDatabase.inMemory();
    repo = createNoteRepository(
      dataDir: tempDir.path,
      defaultAuthor: 'test-device',
      database: db,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('addAttachment copies file and indexes metadata', () async {
    final source = File(p.join(tempDir.path, 'sample.txt'));
    await source.writeAsString('hello attachment');

    final note = await repo.createNote(markdown: 'with file');
    final updated = await repo.addAttachment(note.id, source.path);

    expect(updated.attachments.length, 1);
    expect(updated.attachments.first.name, 'sample.txt');
    expect(updated.attachments.first.size, greaterThan(0));
    expect(updated.attachments.first.sha256, isNotEmpty);

    final onDisk = File(repo.attachmentPath(note.id, 'sample.txt'));
    expect(await onDisk.exists(), isTrue);
    expect(await onDisk.readAsString(), 'hello attachment');

    final reloaded = await repo.getNote(note.id);
    expect(reloaded?.attachments.length, 1);
  });

  test('createNote with attachmentPaths', () async {
    final source = File(p.join(tempDir.path, 'photo.png'));
    await source.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

    final note = await repo.createNote(
      markdown: 'картинка',
      attachmentPaths: [source.path],
    );

    expect(note.attachments.length, 1);
    expect(note.attachments.first.mime, 'image/png');
  });

  test('copyAttachmentIntoNote reports progress', () async {
    final source = File(p.join(tempDir.path, 'large.bin'));
    await source.writeAsBytes(List.filled(64 * 1024, 7));

    final progressEvents = <AttachmentCopyProgress>[];
    await copyAttachmentIntoNote(
      attachmentsDir: p.join(tempDir.path, 'note', 'attachments'),
      sourcePath: source.path,
      onProgress: progressEvents.add,
    );

    expect(progressEvents, isNotEmpty);
    expect(progressEvents.last.copiedBytes, 64 * 1024);
    expect(progressEvents.last.totalBytes, 64 * 1024);
    expect(progressEvents.last.fraction, 1.0);
  });
}
