import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../security/device_signing.dart';
/// UTC timestamp of the signed request (ISO-8601).
const meshpadSyncTimestampHeader = 'X-MeshPad-Timestamp';

/// Base64 Ed25519 signature over [buildSyncSignatureMessage].
const meshpadSyncSignatureHeader = 'X-MeshPad-Signature';

/// Allowed clock skew for signed sync requests.
const syncSignatureMaxSkew = Duration(minutes: 5);

final _ed25519 = Ed25519();

/// Canonical message for LAN sync request signing (PLAN §11.2.8).
String buildSyncSignatureMessage({
  required String peerId,
  required String timestampIso,
  required String method,
  required String path,
}) {
  return 'v1\n$peerId\n$timestampIso\n${method.toUpperCase()}\n$path';
}

/// Headers to attach on authenticated sync HTTP calls.
Future<Map<String, String>> syncSignatureHeaders({
  required String peerId,
  required Uint8List privateKeyBytes,
  required String method,
  required String path,
  DateTime? timestampUtc,
}) async {
  final ts = (timestampUtc ?? DateTime.now()).toUtc();
  final timestampIso = ts.toIso8601String();
  final message = utf8.encode(
    buildSyncSignatureMessage(
      peerId: peerId,
      timestampIso: timestampIso,
      method: method,
      path: path,
    ),
  );
  final keyPair = await _ed25519.newKeyPairFromSeed(privateKeyBytes);
  final signature = await _ed25519.sign(message, keyPair: keyPair);
  return {
    meshpadSyncTimestampHeader: timestampIso,
    meshpadSyncSignatureHeader: base64Encode(signature.bytes),
  };
}

/// Verifies peer [publicKeyBase64] signed this request.
Future<bool> verifySyncRequestSignature({
  required String peerId,
  required String publicKeyBase64,
  required String timestampIso,
  required String method,
  required String path,
  required String signatureBase64,
  DateTime? nowUtc,
}) async {
  final ts = DateTime.tryParse(timestampIso)?.toUtc();
  if (ts == null) return false;

  final now = (nowUtc ?? DateTime.now()).toUtc();
  if (now.difference(ts).abs() > syncSignatureMaxSkew) return false;

  final message = utf8.encode(
    buildSyncSignatureMessage(
      peerId: peerId,
      timestampIso: timestampIso,
      method: method,
      path: path,
    ),
  );

  Uint8List signatureBytes;
  Uint8List publicKeyBytes;
  try {
    signatureBytes = Uint8List.fromList(base64Decode(signatureBase64.trim()));
    publicKeyBytes = deviceSigningPublicKeyFromBase64(publicKeyBase64);
  } catch (_) {
    return false;
  }

  return verifyDeviceMessageSignature(
    message: Uint8List.fromList(message),
    signatureBytes: signatureBytes,
    publicKeyBytes: publicKeyBytes,
  );
}
