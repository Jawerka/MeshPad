import 'package:meshpad_core/meshpad_core.dart';

String noteAttachmentPath(
  Note note,
  AttachmentMeta attachment,
  String dataDir,
) {
  return MeshPadPaths(dataDir).attachmentFile(note.id, attachment.name);
}
