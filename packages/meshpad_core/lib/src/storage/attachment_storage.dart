import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/attachment_copy_progress.dart';
import '../models/note_meta.dart';
import '../errors/meshpad_exception.dart';

/// MIME guess from file extension (MVP — no magic bytes).
String? mimeFromFileName(String name) {
  return switch (p.extension(name).toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.bmp' => 'image/bmp',
    '.svg' => 'image/svg+xml',
    '.pdf' => 'application/pdf',
    '.txt' => 'text/plain',
    '.md' => 'text/markdown',
    _ => null,
  };
}

bool isImageAttachment(AttachmentMeta attachment) {
  final mime = attachment.mime ?? mimeFromFileName(attachment.name);
  return mime?.startsWith('image/') ?? false;
}

Future<AttachmentMeta> copyAttachmentIntoNote({
  required String attachmentsDir,
  required String sourcePath,
  String? preferredName,
  AttachmentCopyProgressCallback? onProgress,
  int fileIndex = 1,
  int fileCount = 1,
}) async {
  final source = File(sourcePath);
  if (!await source.exists()) {
    throw AttachmentNotFoundException(sourcePath);
  }

  await Directory(attachmentsDir).create(recursive: true);

  final baseName = preferredName ?? p.basename(sourcePath);
  final safeName = _uniqueName(attachmentsDir, baseName);
  final dest = File(p.join(attachmentsDir, safeName));
  final totalBytes = await source.length();

  onProgress?.call(
    AttachmentCopyProgress(
      fileName: safeName,
      copiedBytes: 0,
      totalBytes: totalBytes,
      fileIndex: fileIndex,
      fileCount: fileCount,
    ),
  );

  final input = source.openRead();
  final output = dest.openWrite();
  var copiedBytes = 0;

  await input.forEach((chunk) {
    output.add(chunk);
    copiedBytes += chunk.length;
    onProgress?.call(
      AttachmentCopyProgress(
        fileName: safeName,
        copiedBytes: copiedBytes,
        totalBytes: totalBytes,
        fileIndex: fileIndex,
        fileCount: fileCount,
      ),
    );
  });

  await output.flush();
  await output.close();
  final hash = await sha256OfFile(dest.path);

  return AttachmentMeta(
    name: safeName,
    size: copiedBytes,
    mime: mimeFromFileName(safeName),
    sha256: hash,
  );
}

String _uniqueName(String dir, String name) {
  if (!File(p.join(dir, name)).existsSync()) return name;
  final stem = p.basenameWithoutExtension(name);
  final ext = p.extension(name);
  var i = 1;
  while (File(p.join(dir, '$stem ($i)$ext')).existsSync()) {
    i++;
  }
  return '$stem ($i)$ext';
}

Future<String> sha256OfFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return sha256.convert(bytes).toString();
}

String attachmentReferenceMarkdown(String fileName) =>
    '![$fileName](attachments/${Uri.encodeComponent(fileName)})';
