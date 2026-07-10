import 'package:path/path.dart' as p;

import 'attachment_thumbnails.dart';

/// Standard data directory layout (see docs/DATA_LAYOUT.md).
class MeshPadPaths {
  MeshPadPaths(this.root);

  final String root;

  String get notesRoot => p.join(root, 'notes');
  String get devicesRoot => p.join(root, 'devices');
  String get syncRoot => p.join(root, 'sync');

  String get operationsRoot => p.join(root, 'operations');

  String get localIdentityFile => p.join(devicesRoot, 'local_identity.json');

  /// Written when the signing private key was lost and a new pair was generated.
  String get signingKeyResetMarkerFile =>
      p.join(devicesRoot, 'signing_key_reset.json');

  /// Ed25519 private key (base64); not synced (PLAN §11.2.7).
  String get deviceSigningPrivateKeyFile =>
      p.join(devicesRoot, '.device_signing_key');

  String get tlsRoot => p.join(devicesRoot, 'tls');

  String trustedDeviceFile(String peerId) =>
      p.join(devicesRoot, 'trusted', '$peerId.json');

  String noteDir(String id) => p.join(notesRoot, id);

  String noteHistoryDir(String noteId) => p.join(noteDir(noteId), 'history');

  String noteHistoryRevisionDir(String noteId, int revision) =>
      p.join(noteHistoryDir(noteId), '$revision');

  String attachmentsDir(String noteId) =>
      p.join(noteDir(noteId), 'attachments');

  String attachmentFile(String noteId, String fileName) =>
      p.join(attachmentsDir(noteId), fileName);

  String thumbsDir(String noteId) => p.join(noteDir(noteId), '.thumbs');

  String thumbFile(String noteId, String attachmentName) =>
      p.join(thumbsDir(noteId), thumbFileName(attachmentName));
}
