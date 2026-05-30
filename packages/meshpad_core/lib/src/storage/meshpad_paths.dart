import 'package:path/path.dart' as p;

/// Standard data directory layout (see PLAN.md).
class MeshPadPaths {
  MeshPadPaths(this.root);

  final String root;

  String get notesRoot => p.join(root, 'notes');
  String get devicesRoot => p.join(root, 'devices');
  String get syncRoot => p.join(root, 'sync');

  String get localIdentityFile => p.join(devicesRoot, 'local_identity.json');

  String trustedDeviceFile(String peerId) => p.join(devicesRoot, 'trusted', '$peerId.json');

  String noteDir(String id) => p.join(notesRoot, id);

  String attachmentsDir(String noteId) => p.join(noteDir(noteId), 'attachments');

  String attachmentFile(String noteId, String fileName) =>
      p.join(attachmentsDir(noteId), fileName);

  String thumbsDir(String noteId) => p.join(noteDir(noteId), '.thumbs');
}
