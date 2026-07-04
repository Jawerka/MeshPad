import 'package:path/path.dart' as p;

import '../errors/meshpad_exception.dart';

/// Max attachment upload size (PLAN §11.2.5).
const attachmentUploadMaxBytes = 100 * 1024 * 1024;

/// Dangerous extensions rejected for sync/API uploads.
const Set<String> blockedAttachmentExtensions = {
  '.exe',
  '.bat',
  '.cmd',
  '.com',
  '.scr',
  '.pif',
  '.msi',
  '.dll',
  '.vbs',
  '.js',
  '.jse',
  '.wsf',
  '.ps1',
  '.reg',
  '.hta',
  '.cpl',
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
  if (ext.isEmpty) {
    throw const AttachmentUploadRejectedException(
      'invalid_name',
      'Attachment file name must include an extension',
    );
  }

  if (blockedAttachmentExtensions.contains(ext)) {
    throw AttachmentUploadRejectedException(
      'disallowed_type',
      'File type not allowed: $ext',
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
