import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';

import 'attachment_grid.dart';

class AttachmentMediaSource {
  const AttachmentMediaSource.file(
    this.path, {
    this.thumbPath,
  })  : url = null,
        thumbUrl = null,
        missing = false;

  const AttachmentMediaSource.network(this.url, {this.thumbUrl})
      : path = null,
        thumbPath = null,
        missing = false;

  const AttachmentMediaSource.missing()
      : path = null,
        url = null,
        thumbPath = null,
        thumbUrl = null,
        missing = true;

  final String? path;
  final String? url;
  final String? thumbUrl;
  final String? thumbPath;
  final bool missing;

  bool get isAvailable => !missing && (path != null || url != null);

  String get primary => url ?? path ?? '';

  String? get previewUrl => thumbUrl ?? thumbPath ?? url ?? path;
}

AttachmentMediaSource resolveAttachmentMediaSource({
  required Note note,
  required AttachmentMeta attachment,
  String? dataDir,
  Uri? Function(AttachmentMeta attachment)? attachmentUriBuilder,
  Uri? Function(AttachmentMeta attachment)? attachmentThumbUriBuilder,
}) {
  final remote = attachmentUriBuilder?.call(attachment);
  if (remote != null) {
    final thumbRemote = isImageAttachment(attachment)
        ? attachmentThumbUriBuilder?.call(attachment)
        : null;
    return AttachmentMediaSource.network(
      remote.toString(),
      thumbUrl: thumbRemote?.toString(),
    );
  }
  final dir = dataDir;
  if (dir != null) {
    final paths = MeshPadPaths(dir);
    final filePath = noteAttachmentPath(note, attachment, dir);
    String? thumbPath;
    if (isImageAttachment(attachment)) {
      final thumb = paths.thumbFile(note.id, attachment.name);
      if (File(thumb).existsSync()) {
        thumbPath = thumb;
      }
    }
    return AttachmentMediaSource.file(filePath, thumbPath: thumbPath);
  }
  return const AttachmentMediaSource.missing();
}
