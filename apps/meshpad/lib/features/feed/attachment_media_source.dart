import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';

import 'attachment_grid.dart';

class AttachmentMediaSource {
  const AttachmentMediaSource.file(
    this.path, {
    this.thumbPath,
  })  : url = null,
        missing = false;

  const AttachmentMediaSource.network(this.url)
      : path = null,
        thumbPath = null,
        missing = false;

  const AttachmentMediaSource.missing()
      : path = null,
        url = null,
        thumbPath = null,
        missing = true;

  final String? path;
  final String? url;
  final String? thumbPath;
  final bool missing;

  bool get isAvailable => !missing && (path != null || url != null);

  String get primary => url ?? path ?? '';

  String? get previewPath => thumbPath ?? path;
}

AttachmentMediaSource resolveAttachmentMediaSource({
  required Note note,
  required AttachmentMeta attachment,
  String? dataDir,
  Uri? Function(AttachmentMeta attachment)? attachmentUriBuilder,
}) {
  final remote = attachmentUriBuilder?.call(attachment);
  if (remote != null) {
    return AttachmentMediaSource.network(remote.toString());
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
