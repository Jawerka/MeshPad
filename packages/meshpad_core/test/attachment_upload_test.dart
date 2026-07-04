import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String attachmentsDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_upload_');
    attachmentsDir = '${tempDir.path}/attachments';
    await Directory(attachmentsDir).create(recursive: true);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('receives chunked upload and verifies sha256', () async {
    final bytes = List<int>.generate(300 * 1024, (i) => i % 251);
    final hash = sha256.convert(bytes).toString();
    const meta = AttachmentMeta(
      name: 'large.txt',
      size: 300 * 1024,
      sha256: 'placeholder',
    );
    final metaWithHash = AttachmentMeta(
      name: meta.name,
      size: meta.size,
      sha256: hash,
    );

    var offset = 0;
    while (offset < bytes.length) {
      final end = offset + attachmentUploadChunkSize > bytes.length
          ? bytes.length
          : offset + attachmentUploadChunkSize;
      final result = await receiveAttachmentUploadChunk(
        attachmentsDir: attachmentsDir,
        meta: metaWithHash,
        offset: offset,
        totalSize: bytes.length,
        sha256: hash,
        bytes: bytes.sublist(offset, end),
      );
      offset = result.received;
      if (result.complete) break;
    }

    expect(
      await attachmentFileMatches(
        File('$attachmentsDir/${meta.name}'),
        metaWithHash,
      ),
      isTrue,
    );
  });

  test('resumes upload from partial state', () async {
    final bytes = List<int>.generate(300 * 1024, (i) => i % 127);
    final hash = sha256.convert(bytes).toString();
    final meta =
        AttachmentMeta(name: 'resume.txt', size: bytes.length, sha256: hash);

    final firstChunkEnd = attachmentUploadChunkSize;
    await receiveAttachmentUploadChunk(
      attachmentsDir: attachmentsDir,
      meta: meta,
      offset: 0,
      totalSize: bytes.length,
      sha256: hash,
      bytes: bytes.sublist(0, firstChunkEnd),
    );

    var offset = firstChunkEnd;
    while (offset < bytes.length) {
      final end = offset + attachmentUploadChunkSize > bytes.length
          ? bytes.length
          : offset + attachmentUploadChunkSize;
      final result = await receiveAttachmentUploadChunk(
        attachmentsDir: attachmentsDir,
        meta: meta,
        offset: offset,
        totalSize: bytes.length,
        sha256: hash,
        bytes: bytes.sublist(offset, end),
      );
      offset = result.received;
      if (result.complete) break;
    }

    expect(
      await attachmentFileMatches(File('$attachmentsDir/${meta.name}'), meta),
      isTrue,
    );
  });

  test('rejects wrong offset', () async {
    final bytes = List<int>.generate(512, (i) => i);
    final hash = sha256.convert(bytes).toString();
    final meta =
        AttachmentMeta(name: 'small.txt', size: bytes.length, sha256: hash);

    expect(
      () => receiveAttachmentUploadChunk(
        attachmentsDir: attachmentsDir,
        meta: meta,
        offset: 10,
        totalSize: bytes.length,
        sha256: hash,
        bytes: bytes,
      ),
      throwsA(isA<AttachmentUploadOffsetException>()),
    );
  });
}
