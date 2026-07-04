/// Parsed note attachment path from LAN HTTP suffix.
class LanAttachmentPath {
  const LanAttachmentPath({required this.noteId, required this.fileName});

  final String noteId;
  final String fileName;
}

/// Parses `noteId/attachments/fileName` from a LAN route suffix.
LanAttachmentPath? parseLanAttachmentPath(String suffix) {
  const marker = '/attachments/';
  final index = suffix.indexOf(marker);
  if (index < 0) return null;

  final noteId = suffix.substring(0, index);
  final fileName = Uri.decodeComponent(suffix.substring(index + marker.length));
  if (noteId.isEmpty || fileName.isEmpty) return null;

  return LanAttachmentPath(noteId: noteId, fileName: fileName);
}

/// Strips resumable upload suffix when present.
String attachmentPathWithoutUploadSuffix(String suffix) {
  const uploadSuffix = '/upload';
  if (suffix.endsWith(uploadSuffix)) {
    return suffix.substring(0, suffix.length - uploadSuffix.length);
  }
  return suffix;
}
