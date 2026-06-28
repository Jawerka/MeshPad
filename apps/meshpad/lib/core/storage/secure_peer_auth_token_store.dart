import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meshpad_core/meshpad_core.dart';

/// Platform secure storage for LAN sync auth tokens (PLAN §11.2.1).
class SecurePeerAuthTokenStore implements PeerAuthTokenStore {
  SecurePeerAuthTokenStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _keyPrefix = 'meshpad_auth_token_';

  String _key(String peerId) => '$_keyPrefix$peerId';

  @override
  Future<String?> read(String peerId) => _storage.read(key: _key(peerId));

  @override
  Future<void> write(String peerId, String token) =>
      _storage.write(key: _key(peerId), value: token);

  @override
  Future<void> delete(String peerId) => _storage.delete(key: _key(peerId));
}
