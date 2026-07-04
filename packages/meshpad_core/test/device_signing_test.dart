import 'dart:convert';
import 'dart:typed_data';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('generateDeviceSigningKeyPair produces verifiable Ed25519 keys',
      () async {
    final pair = await generateDeviceSigningKeyPair();
    expect(pair.algorithm, deviceSigningAlgorithmEd25519);
    expect(pair.publicKeyBytes.length, 32);
    expect(pair.privateKeyBytes.isNotEmpty, isTrue);

    final message = Uint8List.fromList(utf8.encode('meshpad-sync-challenge'));
    final signature = await signDeviceMessage(
      message: message,
      privateKeyBytes: pair.privateKeyBytes,
    );
    final ok = await verifyDeviceMessageSignature(
      message: message,
      signatureBytes: signature,
      publicKeyBytes: pair.publicKeyBytes,
    );
    expect(ok, isTrue);
  });
}
