import 'package:meshpad_core/meshpad_core.dart';

import 'attachment_grid.dart';

class AttachmentMediaSource {
  const AttachmentMediaSource.file(this.path) : url = null, missing = false;

  const AttachmentMediaSource.network(this.url) : path = null, missing = false;

  const AttachmentMediaSource.missing() : path = null, url = null, missing = true;

  final String? path;
  final String? url;
  final bool missing;

  bool get isAvailable => !missing && (path != null || url != null);

  String get primary => url ?? path ?? '';
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
    return AttachmentMediaSource.file(
      noteAttachmentPath(note, attachment, dir),
    );
  }
  return const AttachmentMediaSource.missing();
}
