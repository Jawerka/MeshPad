import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/attachment_copy_progress.dart';
import '../models/note_meta.dart';
import '../errors/meshpad_exception.dart';
import 'attachment_thumbnails.dart';

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
    '.mp4' => 'video/mp4',
    '.webm' => 'video/webm',
    '.mov' => 'video/quicktime',
    '.mkv' => 'video/x-matroska',
    '.avi' => 'video/x-msvideo',
    '.m4v' => 'video/x-m4v',
    '.mp3' => 'audio/mpeg',
    '.m4a' => 'audio/mp4',
    '.wav' => 'audio/wav',
    '.ogg' || '.oga' => 'audio/ogg',
    '.opus' => 'audio/opus',
    '.flac' => 'audio/flac',
    '.aac' => 'audio/aac',
    '.weba' => 'audio/webm',
    _ => null,
  };
}

String? attachmentMime(AttachmentMeta attachment) =>
    attachment.mime ?? mimeFromFileName(attachment.name);

enum AttachmentPreviewKind { image, video, audio, file }

AttachmentPreviewKind attachmentPreviewKind(AttachmentMeta attachment) {
  final mime = attachmentMime(attachment);
  if (mime == null) return AttachmentPreviewKind.file;
  if (mime.startsWith('image/')) return AttachmentPreviewKind.image;
  if (mime.startsWith('video/')) return AttachmentPreviewKind.video;
  if (mime.startsWith('audio/')) return AttachmentPreviewKind.audio;
  return AttachmentPreviewKind.file;
}

bool isImageAttachment(AttachmentMeta attachment) =>
    attachmentPreviewKind(attachment) == AttachmentPreviewKind.image;

bool isVideoAttachment(AttachmentMeta attachment) =>
    attachmentPreviewKind(attachment) == AttachmentPreviewKind.video;

bool isAudioAttachment(AttachmentMeta attachment) =>
    attachmentPreviewKind(attachment) == AttachmentPreviewKind.audio;

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

  await ensureImageThumbnail(
    attachmentPath: dest.path,
    thumbsDir: thumbsDirForAttachmentsDir(attachmentsDir),
    attachmentName: safeName,
  );

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

/// Returns true when [file] exists and matches [meta] size (and sha256 if set).
Future<bool> attachmentFileMatches(File file, AttachmentMeta meta) async {
  if (!await file.exists()) return false;
  final length = await file.length();
  if (length != meta.size) return false;
  if (meta.sha256 == null) return true;
  return await sha256OfFile(file.path) == meta.sha256;
}

/// Writes attachment bytes into [attachmentsDir] and returns metadata.
Future<AttachmentMeta> createAttachmentFromBytes({
  required String attachmentsDir,
  required String preferredName,
  required List<int> bytes,
  AttachmentCopyProgressCallback? onProgress,
  int fileIndex = 1,
  int fileCount = 1,
}) async {
  await Directory(attachmentsDir).create(recursive: true);

  final safeName = _uniqueName(attachmentsDir, preferredName);
  final dest = File(p.join(attachmentsDir, safeName));
  final totalBytes = bytes.length;

  onProgress?.call(
    AttachmentCopyProgress(
      fileName: safeName,
      copiedBytes: 0,
      totalBytes: totalBytes,
      fileIndex: fileIndex,
      fileCount: fileCount,
    ),
  );

  await dest.writeAsBytes(bytes, flush: true);

  onProgress?.call(
    AttachmentCopyProgress(
      fileName: safeName,
      copiedBytes: totalBytes,
      totalBytes: totalBytes,
      fileIndex: fileIndex,
      fileCount: fileCount,
    ),
  );

  await ensureImageThumbnail(
    attachmentPath: dest.path,
    thumbsDir: thumbsDirForAttachmentsDir(attachmentsDir),
    attachmentName: safeName,
  );

  final hash = await sha256OfFile(dest.path);
  return AttachmentMeta(
    name: safeName,
    size: totalBytes,
    mime: mimeFromFileName(safeName),
    sha256: hash,
  );
}

Future<AttachmentMeta> writeAttachmentBytes({
  required String attachmentsDir,
  required AttachmentMeta meta,
  required List<int> bytes,
}) async {
  if (bytes.length != meta.size) {
    throw StateError(
      'Attachment size mismatch for ${meta.name}: expected ${meta.size}, got ${bytes.length}',
    );
  }

  await Directory(attachmentsDir).create(recursive: true);
  final dest = File(p.join(attachmentsDir, meta.name));
  await dest.writeAsBytes(bytes, flush: true);

  if (meta.sha256 != null) {
    final hash = await sha256OfFile(dest.path);
    if (hash != meta.sha256) {
      await dest.delete();
      throw StateError('Attachment sha256 mismatch for ${meta.name}');
    }
  }

  await ensureImageThumbnail(
    attachmentPath: dest.path,
    thumbsDir: thumbsDirForAttachmentsDir(attachmentsDir),
    attachmentName: meta.name,
  );

  return meta;
}

String attachmentReferenceMarkdown(String fileName) =>
    '![$fileName](attachments/${Uri.encodeComponent(fileName)})';
