import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Device signing keys for future challenge-response sync (PLAN §11.2.7).
class DeviceSigningKeyPair {
  const DeviceSigningKeyPair({
    required this.algorithm,
    required this.publicKeyBytes,
    required this.privateKeyBytes,
  });

  final String algorithm;
  final Uint8List publicKeyBytes;
  final Uint8List privateKeyBytes;

  String get publicKeyBase64 => base64Encode(publicKeyBytes);
}

const deviceSigningAlgorithmEd25519 = 'ed25519';

final _ed25519 = Ed25519();

/// Generates an Ed25519 key pair for local device identity.
Future<DeviceSigningKeyPair> generateDeviceSigningKeyPair() async {
  final pair = await _ed25519.newKeyPair();
  final publicKey = await pair.extractPublicKey();
  final privateKey = await pair.extractPrivateKeyBytes();
  return DeviceSigningKeyPair(
    algorithm: deviceSigningAlgorithmEd25519,
    publicKeyBytes: Uint8List.fromList(publicKey.bytes),
    privateKeyBytes: Uint8List.fromList(privateKey),
  );
}

Uint8List deviceSigningPublicKeyFromBase64(String encoded) {
  return Uint8List.fromList(base64Decode(encoded.trim()));
}

/// Signs [message] with the device private key (for tests and future sync auth).
Future<Uint8List> signDeviceMessage({
  required Uint8List message,
  required Uint8List privateKeyBytes,
}) async {
  final keyPair = await _ed25519.newKeyPairFromSeed(privateKeyBytes);
  final signature = await _ed25519.sign(message, keyPair: keyPair);
  return Uint8List.fromList(signature.bytes);
}

/// Verifies a signature from a peer's public key.
Future<bool> verifyDeviceMessageSignature({
  required Uint8List message,
  required Uint8List signatureBytes,
  required Uint8List publicKeyBytes,
}) async {
  final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
  return _ed25519.verify(
    message,
    signature: Signature(signatureBytes, publicKey: publicKey),
  );
}
