import 'dart:io';

import 'package:path/path.dart' as p;

import 'meshpad_paths.dart';
import 'peer_auth_token_store.dart';

/// File-backed auth tokens (`devices/auth_tokens/<peer_id>.token`).
class FilePeerAuthTokenStore implements PeerAuthTokenStore {
  FilePeerAuthTokenStore({required MeshPadPaths paths})
      : _dir = Directory(p.join(paths.devicesRoot, 'auth_tokens'));

  final Directory _dir;

  File _fileFor(String peerId) => File(p.join(_dir.path, '$peerId.token'));

  Future<void> _ensureDir() async {
    if (!await _dir.exists()) {
      await _dir.create(recursive: true);
    }
  }

  @override
  Future<String?> read(String peerId) async {
    final file = _fileFor(peerId);
    if (!await file.exists()) return null;
    final token = (await file.readAsString()).trim();
    return token.isEmpty ? null : token;
  }

  @override
  Future<void> write(String peerId, String token) async {
    await _ensureDir();
    await _fileFor(peerId).writeAsString(token);
  }

  @override
  Future<void> delete(String peerId) async {
    final file = _fileFor(peerId);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
