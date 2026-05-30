import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/note_meta.dart';

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
}) async {
  final source = File(sourcePath);
  if (!await source.exists()) {
    throw StateError('Attachment source not found: $sourcePath');
  }

  await Directory(attachmentsDir).create(recursive: true);

  final baseName = preferredName ?? p.basename(sourcePath);
  final safeName = _uniqueName(attachmentsDir, baseName);
  final dest = File(p.join(attachmentsDir, safeName));
  await source.copy(dest.path);

  final bytes = await dest.readAsBytes();
  final digest = sha256.convert(bytes).toString();

  return AttachmentMeta(
    name: safeName,
    size: bytes.length,
    mime: mimeFromFileName(safeName),
    sha256: digest,
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
