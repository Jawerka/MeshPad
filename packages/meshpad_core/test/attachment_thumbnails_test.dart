import 'dart:io';

import 'package:image/image.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_thumb_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('ensureImageThumbnail writes JPEG preview in .thumbs', () async {
    final attachmentsDir = p.join(tempDir.path, 'note', 'attachments');
    await Directory(attachmentsDir).create(recursive: true);

    final sourcePath = p.join(attachmentsDir, 'photo.png');
    final png = encodePng(Image(width: 640, height: 480));
    await File(sourcePath).writeAsBytes(png);

    await ensureImageThumbnail(
      attachmentPath: sourcePath,
      thumbsDir: thumbsDirForAttachmentsDir(attachmentsDir),
      attachmentName: 'photo.png',
      maxEdge: 240,
    );

    final thumbPath = p.join(
      thumbsDirForAttachmentsDir(attachmentsDir),
      thumbFileName('photo.png'),
    );
    final thumb = File(thumbPath);
    expect(await thumb.exists(), isTrue);

    final decoded = decodeImage(await thumb.readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(240));
    expect(decoded.height, lessThanOrEqualTo(240));
  });

  test('copyAttachmentIntoNote generates thumbnail for images', () async {
    final attachmentsDir = p.join(tempDir.path, 'attachments');
    final sourcePath = p.join(tempDir.path, 'input.png');
    await File(sourcePath)
        .writeAsBytes(encodePng(Image(width: 400, height: 300)));

    await copyAttachmentIntoNote(
      attachmentsDir: attachmentsDir,
      sourcePath: sourcePath,
    );

    final thumbPath = p.join(
      thumbsDirForAttachmentsDir(attachmentsDir),
      thumbFileName('input.png'),
    );
    expect(await File(thumbPath).exists(), isTrue);
  });

  test('ensureImageThumbnail skips non-image files', () async {
    final attachmentsDir = p.join(tempDir.path, 'attachments');
    await Directory(attachmentsDir).create(recursive: true);
    final sourcePath = p.join(attachmentsDir, 'readme.txt');
    await File(sourcePath).writeAsString('hello');

    await ensureImageThumbnail(
      attachmentPath: sourcePath,
      thumbsDir: thumbsDirForAttachmentsDir(attachmentsDir),
      attachmentName: 'readme.txt',
    );

    expect(
      await Directory(thumbsDirForAttachmentsDir(attachmentsDir)).exists(),
      isFalse,
    );
  });
}
