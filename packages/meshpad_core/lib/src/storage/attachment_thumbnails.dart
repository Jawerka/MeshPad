import 'dart:io';

import 'package:image/image.dart';
import 'package:path/path.dart' as p;

import 'attachment_storage.dart';

const defaultThumbMaxEdge = 240;

String thumbFileName(String attachmentName) {
  final stem = p.basenameWithoutExtension(attachmentName);
  return '$stem.jpg';
}

String thumbsDirForAttachmentsDir(String attachmentsDir) =>
    p.join(p.dirname(attachmentsDir), '.thumbs');

/// Generates a JPEG preview in [.thumbs] for raster image attachments (PLAN §3.1).
Future<void> ensureImageThumbnail({
  required String attachmentPath,
  required String thumbsDir,
  required String attachmentName,
  int maxEdge = defaultThumbMaxEdge,
}) async {
  final mime = mimeFromFileName(attachmentName);
  if (mime == null || !mime.startsWith('image/')) return;
  if (mime == 'image/svg+xml' || mime == 'image/gif') return;

  final source = File(attachmentPath);
  if (!await source.exists()) return;

  Image? decoded;
  try {
    decoded = decodeImage(await source.readAsBytes());
  } catch (_) {
    return;
  }
  if (decoded == null) return;

  final resized = _resizeToFit(decoded, maxEdge);
  await Directory(thumbsDir).create(recursive: true);
  await File(p.join(thumbsDir, thumbFileName(attachmentName))).writeAsBytes(
    encodeJpg(resized, quality: 85),
    flush: true,
  );
}

Image _resizeToFit(Image source, int maxEdge) {
  if (source.width <= maxEdge && source.height <= maxEdge) {
    return source;
  }
  if (source.width >= source.height) {
    return copyResize(source, width: maxEdge);
  }
  return copyResize(source, height: maxEdge);
}

/// Returns an on-disk JPEG preview, generating or refreshing it when needed.
Future<File?> resolveImageThumbnailFile({
  required String attachmentPath,
  required String thumbsDir,
  required String attachmentName,
  int maxEdge = defaultThumbMaxEdge,
}) async {
  final mime = mimeFromFileName(attachmentName);
  if (mime == null || !mime.startsWith('image/')) return null;
  if (mime == 'image/svg+xml' || mime == 'image/gif') return null;

  final source = File(attachmentPath);
  if (!await source.exists()) return null;

  final thumbPath = p.join(thumbsDir, thumbFileName(attachmentName));
  final thumb = File(thumbPath);
  final needsBuild = !await thumb.exists() ||
      (await source.lastModified()).isAfter(await thumb.lastModified());

  if (needsBuild) {
    await ensureImageThumbnail(
      attachmentPath: attachmentPath,
      thumbsDir: thumbsDir,
      attachmentName: attachmentName,
      maxEdge: maxEdge,
    );
  }

  return await thumb.exists() ? thumb : null;
}
