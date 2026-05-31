import 'dart:io';

import 'package:image/image.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_thumb_resolve_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('resolveImageThumbnailFile generates missing preview', () async {
    final attachmentsDir = p.join(tempDir.path, 'note', 'attachments');
    await Directory(attachmentsDir).create(recursive: true);

    final sourcePath = p.join(attachmentsDir, 'photo.png');
    await File(sourcePath).writeAsBytes(encodePng(Image(width: 800, height: 600)));

    final thumbFile = await resolveImageThumbnailFile(
      attachmentPath: sourcePath,
      thumbsDir: thumbsDirForAttachmentsDir(attachmentsDir),
      attachmentName: 'photo.png',
    );

    expect(thumbFile, isNotNull);
    expect(await thumbFile!.exists(), isTrue);
    final decoded = decodeImage(await thumbFile.readAsBytes());
    expect(decoded!.width, lessThanOrEqualTo(240));
  });

  test('resolveImageThumbnailFile refreshes stale preview', () async {
    final attachmentsDir = p.join(tempDir.path, 'note', 'attachments');
    final thumbsDir = thumbsDirForAttachmentsDir(attachmentsDir);
    await Directory(attachmentsDir).create(recursive: true);
    await Directory(thumbsDir).create(recursive: true);

    final sourcePath = p.join(attachmentsDir, 'photo.png');
    await File(sourcePath).writeAsBytes(encodePng(Image(width: 400, height: 300)));

    final staleThumb = File(p.join(thumbsDir, thumbFileName('photo.png')));
    await staleThumb.writeAsBytes(encodeJpg(Image(width: 10, height: 10)));
    await staleThumb.setLastModified(DateTime(2000));

    final thumbFile = await resolveImageThumbnailFile(
      attachmentPath: sourcePath,
      thumbsDir: thumbsDir,
      attachmentName: 'photo.png',
    );

    final decoded = decodeImage(await thumbFile!.readAsBytes());
    expect(decoded!.width, greaterThan(10));
  });
}
