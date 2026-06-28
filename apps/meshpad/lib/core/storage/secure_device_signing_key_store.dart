import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meshpad_core/meshpad_core.dart';

/// Platform secure storage for the device Ed25519 private key (PLAN §11.2.7).
class SecureDeviceSigningKeyStore implements DeviceSigningKeyStore {
  SecureDeviceSigningKeyStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _storageKey = 'meshpad_device_signing_private_key';

  @override
  Future<Uint8List?> readPrivateKey() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return null;
    return Uint8List.fromList(base64Decode(raw));
  }

  @override
  Future<void> writePrivateKey(Uint8List bytes) async {
    await _storage.write(
      key: _storageKey,
      value: base64Encode(bytes),
    );
  }

  @override
  Future<void> delete() => _storage.delete(key: _storageKey);
}
