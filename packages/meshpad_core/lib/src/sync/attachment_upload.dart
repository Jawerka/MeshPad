import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../errors/meshpad_exception.dart';
import '../models/note_meta.dart';
import '../security/attachment_upload_policy.dart';
import '../storage/attachment_storage.dart';
import '../storage/attachment_thumbnails.dart';

/// Chunk size for resumable LAN attachment uploads.
const attachmentUploadChunkSize = 256 * 1024;

/// Files larger than this use chunked/resumable upload (PLAN §12 C.3).
const attachmentUploadChunkThreshold = attachmentUploadChunkSize;

const meshpadUploadOffsetHeader = 'X-MeshPad-Upload-Offset';
const meshpadUploadTotalHeader = 'X-MeshPad-Upload-Total';
const meshpadUploadSha256Header = 'X-MeshPad-Upload-Sha256';

class AttachmentUploadStatus {
  const AttachmentUploadStatus({
    required this.received,
    required this.total,
    required this.sha256,
  });

  final int received;
  final int total;
  final String sha256;

  bool get isComplete => received >= total && total > 0;

  Map<String, dynamic> toJson() => {
        'received': received,
        'total': total,
        'sha256': sha256,
      };

  factory AttachmentUploadStatus.fromJson(Map<String, dynamic> json) {
    return AttachmentUploadStatus(
      received: json['received'] as int? ?? 0,
      total: json['total'] as int,
      sha256: json['sha256'] as String,
    );
  }
}

class AttachmentUploadResult {
  const AttachmentUploadResult({
    required this.received,
    required this.complete,
  });

  final int received;
  final bool complete;

  Map<String, dynamic> toJson() => {
        'received': received,
        'complete': complete,
      };
}

String partialUploadDir(String attachmentsDir) =>
    p.join(attachmentsDir, '.uploading');

File _partFile(String attachmentsDir, String fileName) =>
    File(p.join(partialUploadDir(attachmentsDir), fileName));

File _metaFile(String attachmentsDir, String fileName) =>
    File(p.join(partialUploadDir(attachmentsDir), '$fileName.meta.json'));

Future<AttachmentUploadStatus?> readAttachmentUploadStatus({
  required String attachmentsDir,
  required String fileName,
  required AttachmentMeta meta,
}) async {
  final finalFile = File(p.join(attachmentsDir, fileName));
  if (await attachmentFileMatches(finalFile, meta)) {
    final sha = meta.sha256 ?? await sha256OfFile(finalFile.path);
    return AttachmentUploadStatus(
      received: meta.size,
      total: meta.size,
      sha256: sha,
    );
  }

  final metaFile = _metaFile(attachmentsDir, fileName);
  if (!await metaFile.exists()) {
    return AttachmentUploadStatus(
      received: 0,
      total: meta.size,
      sha256: meta.sha256 ?? '',
    );
  }

  final json =
      jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
  final status = AttachmentUploadStatus.fromJson(json);
  final part = _partFile(attachmentsDir, fileName);
  final received = await part.exists() ? await part.length() : 0;
  return AttachmentUploadStatus(
    received: received,
    total: status.total,
    sha256: status.sha256,
  );
}

Future<AttachmentUploadResult> receiveAttachmentUploadChunk({
  required String attachmentsDir,
  required AttachmentMeta meta,
  required int offset,
  required int totalSize,
  required String sha256,
  required List<int> bytes,
}) async {
  validateAttachmentUpload(
    fileName: meta.name,
    byteLength: totalSize,
  );

  if (totalSize != meta.size) {
    throw StateError(
      'Upload total mismatch for ${meta.name}: expected ${meta.size}, got $totalSize',
    );
  }
  if (meta.sha256 != null && meta.sha256 != sha256) {
    throw StateError('Upload sha256 mismatch for ${meta.name}');
  }

  final finalFile = File(p.join(attachmentsDir, meta.name));
  if (await attachmentFileMatches(finalFile, meta)) {
    return AttachmentUploadResult(received: meta.size, complete: true);
  }

  await Directory(partialUploadDir(attachmentsDir)).create(recursive: true);
  final partFile = _partFile(attachmentsDir, meta.name);
  final sidecar = _metaFile(attachmentsDir, meta.name);

  var received = await partFile.exists() ? await partFile.length() : 0;
  if (await sidecar.exists()) {
    final existing = AttachmentUploadStatus.fromJson(
      jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>,
    );
    if (existing.total != totalSize || existing.sha256 != sha256) {
      await _clearPartialUpload(attachmentsDir, meta.name);
      received = 0;
    }
  }

  if (offset != received) {
    throw AttachmentUploadOffsetException(received);
  }

  if (received == 0 && offset == 0 && await partFile.exists()) {
    await partFile.delete();
  }

  if (bytes.isEmpty) {
    throw StateError('Empty upload chunk for ${meta.name}');
  }

  if (received + bytes.length > totalSize) {
    throw StateError('Upload chunk exceeds total size for ${meta.name}');
  }

  await sidecar.writeAsString(
    jsonEncode(
      AttachmentUploadStatus(
        received: received,
        total: totalSize,
        sha256: sha256,
      ).toJson(),
    ),
  );

  final sink = partFile.openWrite(
      mode: received == 0 ? FileMode.write : FileMode.append);
  sink.add(bytes);
  await sink.close();

  received += bytes.length;

  if (received < totalSize) {
    return AttachmentUploadResult(received: received, complete: false);
  }

  final hash = await sha256OfFile(partFile.path);
  if (hash != sha256) {
    await _clearPartialUpload(attachmentsDir, meta.name);
    throw StateError('Upload sha256 verification failed for ${meta.name}');
  }

  if (await finalFile.exists()) await finalFile.delete();
  await partFile.rename(finalFile.path);
  await sidecar.delete();

  await ensureImageThumbnail(
    attachmentPath: finalFile.path,
    thumbsDir: thumbsDirForAttachmentsDir(attachmentsDir),
    attachmentName: meta.name,
  );

  return AttachmentUploadResult(received: received, complete: true);
}

Future<void> _clearPartialUpload(String attachmentsDir, String fileName) async {
  final part = _partFile(attachmentsDir, fileName);
  final meta = _metaFile(attachmentsDir, fileName);
  if (await part.exists()) await part.delete();
  if (await meta.exists()) await meta.delete();
}

String sha256OfBytes(List<int> bytes) => sha256.convert(bytes).toString();
