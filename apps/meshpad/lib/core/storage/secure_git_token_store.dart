import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// GitHub OAuth access token and profile for Git sync (desktop).
class SecureGitTokenStore {
  SecureGitTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'meshpad_github_token';
  static const _loginKey = 'meshpad_github_login';

  Future<String?> read() => _storage.read(key: _tokenKey);

  Future<String?> readLogin() => _storage.read(key: _loginKey);

  Future<void> writeSession({
    required String token,
    required String login,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _loginKey, value: login);
  }

  Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> delete() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _loginKey);
  }
}
