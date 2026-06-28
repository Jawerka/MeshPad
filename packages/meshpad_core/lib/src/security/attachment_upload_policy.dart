import 'package:path/path.dart' as p;

import '../errors/meshpad_exception.dart';
import '../storage/attachment_storage.dart';

/// Max attachment upload size (PLAN §11.2.5).
const attachmentUploadMaxBytes = 100 * 1024 * 1024;

/// Extensions allowed for sync/API uploads (must match [mimeFromFileName]).
const Set<String> allowedAttachmentExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.bmp',
  '.svg',
  '.pdf',
  '.txt',
  '.md',
  '.mp4',
  '.webm',
  '.mov',
  '.mkv',
  '.avi',
  '.m4v',
  '.mp3',
  '.m4a',
  '.wav',
  '.ogg',
  '.oga',
  '.opus',
  '.flac',
  '.aac',
  '.weba',
};

/// Validates file name, extension, and size before accepting attachment bytes.
void validateAttachmentUpload({
  required String fileName,
  required int byteLength,
  int maxBytes = attachmentUploadMaxBytes,
}) {
  final base = p.basename(fileName);
  if (base.isEmpty ||
      base != fileName.trim() ||
      base.contains('..') ||
      base.contains('/') ||
      base.contains(r'\')) {
    throw const AttachmentUploadRejectedException(
      'invalid_name',
      'Invalid attachment file name',
    );
  }

  final ext = p.extension(base).toLowerCase();
  if (ext.isEmpty || !allowedAttachmentExtensions.contains(ext)) {
    throw AttachmentUploadRejectedException(
      'disallowed_type',
      'File type not allowed: $ext',
    );
  }

  if (mimeFromFileName(base) == null) {
    throw AttachmentUploadRejectedException(
      'disallowed_type',
      'Unsupported attachment type: $ext',
    );
  }

  if (byteLength <= 0) {
    throw const AttachmentUploadRejectedException(
      'empty_body',
      'Attachment body is empty',
    );
  }

  if (byteLength > maxBytes) {
    throw AttachmentUploadRejectedException(
      'too_large',
      'Attachment exceeds ${maxBytes ~/ (1024 * 1024)} MB limit',
    );
  }
}
