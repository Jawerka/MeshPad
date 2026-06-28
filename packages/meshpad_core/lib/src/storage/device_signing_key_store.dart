import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'meshpad_paths.dart';

/// Stores the device Ed25519 private key outside [local_identity.json] (PLAN §11.2.7).
abstract class DeviceSigningKeyStore {
  Future<Uint8List?> readPrivateKey();

  Future<void> writePrivateKey(Uint8List bytes);

  Future<void> delete() async {}
}

/// File-backed private key for tests and headless (not for production mobile).
class FileDeviceSigningKeyStore implements DeviceSigningKeyStore {
  FileDeviceSigningKeyStore(this._paths);

  final MeshPadPaths _paths;

  File get _file => File(_paths.deviceSigningPrivateKeyFile);

  @override
  Future<Uint8List?> readPrivateKey() async {
    if (!await _file.exists()) return null;
    final raw = (await _file.readAsString()).trim();
    if (raw.isEmpty) return null;
    return Uint8List.fromList(base64Decode(raw));
  }

  @override
  Future<void> writePrivateKey(Uint8List bytes) async {
    await Directory(_paths.devicesRoot).create(recursive: true);
    await _file.writeAsString(base64Encode(bytes));
  }

  @override
  Future<void> delete() async {
    if (await _file.exists()) await _file.delete();
  }
}

/// In-memory only (unit tests).
class MemoryDeviceSigningKeyStore implements DeviceSigningKeyStore {
  Uint8List? _bytes;

  @override
  Future<Uint8List?> readPrivateKey() async => _bytes;

  @override
  Future<void> writePrivateKey(Uint8List bytes) async {
    _bytes = Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete() async {
    _bytes = null;
  }
}
