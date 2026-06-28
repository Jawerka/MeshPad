import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// HTTP header: peer requests encrypted JSON payloads (wire v3).
const meshpadPayloadEncHeader = 'X-MeshPad-Payload-Enc';

/// Header value for [meshpadPayloadEncHeader].
const meshpadPayloadEncValue = 'meshpad-payload-v1';

const _hkdfSalt = 'meshpad-payload-v1';
const _contentTypeEncrypted = 'application/meshpad+json; charset=utf-8';

/// Derives AES-256 key from pairing token and sorted peer ids.
Future<SecretKey> derivePayloadKey({
  required String authToken,
  required String localPeerId,
  required String remotePeerId,
}) async {
  final peers = [localPeerId, remotePeerId]..sort();
  final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  return hkdf.deriveKey(
    secretKey: SecretKey(utf8.encode(authToken)),
    nonce: utf8.encode(_hkdfSalt),
    info: utf8.encode('${peers[0]}|${peers[1]}'),
  );
}

bool requestWantsPayloadEncryption(String? headerValue) =>
    headerValue == meshpadPayloadEncValue;

/// Encrypts UTF-8 JSON bytes into an envelope map.
Future<Map<String, dynamic>> encryptPayloadBytes({
  required List<int> plaintext,
  required String authToken,
  required String localPeerId,
  required String remotePeerId,
}) async {
  final key = await derivePayloadKey(
    authToken: authToken,
    localPeerId: localPeerId,
    remotePeerId: remotePeerId,
  );
  final algorithm = AesGcm.with256bits();
  final nonce = algorithm.newNonce();
  final box = await algorithm.encrypt(
    plaintext,
    secretKey: key,
    nonce: nonce,
  );
  final combined = [...box.cipherText, ...box.mac.bytes];
  return {
    'enc': meshpadPayloadEncValue,
    'nonce': base64Encode(box.nonce),
    'ciphertext': base64Encode(combined),
  };
}

/// Decrypts envelope map to UTF-8 JSON bytes.
Future<List<int>> decryptPayloadEnvelope({
  required Map<String, dynamic> envelope,
  required String authToken,
  required String localPeerId,
  required String remotePeerId,
}) async {
  if (envelope['enc'] != meshpadPayloadEncValue) {
    throw StateError('unsupported payload encryption');
  }
  final nonceRaw = envelope['nonce'] as String?;
  final cipherRaw = envelope['ciphertext'] as String?;
  if (nonceRaw == null || cipherRaw == null) {
    throw StateError('invalid encrypted payload');
  }
  final combined = base64Decode(cipherRaw);
  if (combined.length < 16) {
    throw StateError('ciphertext too short');
  }
  final mac = Mac(combined.sublist(combined.length - 16));
  final cipherText = combined.sublist(0, combined.length - 16);
  final key = await derivePayloadKey(
    authToken: authToken,
    localPeerId: localPeerId,
    remotePeerId: remotePeerId,
  );
  final algorithm = AesGcm.with256bits();
  final clear = await algorithm.decrypt(
    SecretBox(cipherText, nonce: base64Decode(nonceRaw), mac: mac),
    secretKey: key,
  );
  return clear;
}

Future<String> encryptJsonString({
  required String json,
  required String authToken,
  required String localPeerId,
  required String remotePeerId,
}) async {
  final envelope = await encryptPayloadBytes(
    plaintext: utf8.encode(json),
    authToken: authToken,
    localPeerId: localPeerId,
    remotePeerId: remotePeerId,
  );
  return jsonEncode(envelope);
}

Future<String> decryptJsonString({
  required String body,
  required String authToken,
  required String localPeerId,
  required String remotePeerId,
}) async {
  final envelope = jsonDecode(body) as Map<String, dynamic>;
  final clear = await decryptPayloadEnvelope(
    envelope: envelope,
    authToken: authToken,
    localPeerId: localPeerId,
    remotePeerId: remotePeerId,
  );
  return utf8.decode(clear);
}

String encryptedPayloadContentType() => _contentTypeEncrypted;

bool isEncryptedPayloadContentType(String? contentType) =>
    contentType != null && contentType.startsWith('application/meshpad+json');

bool bodyLooksEncrypted(String body) {
  final trimmed = body.trimLeft();
  return trimmed.startsWith('{') && trimmed.contains('"enc"');
}
