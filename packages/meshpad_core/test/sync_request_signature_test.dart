import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('syncSignatureHeaders verify on same canonical message', () async {
    final pair = await generateDeviceSigningKeyPair();
    const peerId = 'peer-a';
    const path = '/meshpad/p2p/catalog';
    final ts = DateTime.utc(2026, 6, 1, 12, 0, 0);

    final headers = await syncSignatureHeaders(
      peerId: peerId,
      privateKeyBytes: pair.privateKeyBytes,
      method: 'GET',
      path: path,
      timestampUtc: ts,
    );

    final ok = await verifySyncRequestSignature(
      peerId: peerId,
      publicKeyBase64: pair.publicKeyBase64,
      timestampIso: headers[meshpadSyncTimestampHeader]!,
      method: 'GET',
      path: path,
      signatureBase64: headers[meshpadSyncSignatureHeader]!,
      nowUtc: ts,
    );
    expect(ok, isTrue);
  });

  test('rejects tampered path', () async {
    final pair = await generateDeviceSigningKeyPair();
    final ts = DateTime.utc(2026, 6, 1, 12);
    final headers = await syncSignatureHeaders(
      peerId: 'peer-a',
      privateKeyBytes: pair.privateKeyBytes,
      method: 'GET',
      path: '/meshpad/p2p/catalog',
      timestampUtc: ts,
    );

    final ok = await verifySyncRequestSignature(
      peerId: 'peer-a',
      publicKeyBase64: pair.publicKeyBase64,
      timestampIso: headers[meshpadSyncTimestampHeader]!,
      method: 'GET',
      path: '/meshpad/p2p/notes/other',
      signatureBase64: headers[meshpadSyncSignatureHeader]!,
      nowUtc: ts,
    );
    expect(ok, isFalse);
  });

  test('rejects expired timestamp', () async {
    final pair = await generateDeviceSigningKeyPair();
    final ts = DateTime.utc(2026, 6, 1, 12);
    final headers = await syncSignatureHeaders(
      peerId: 'peer-a',
      privateKeyBytes: pair.privateKeyBytes,
      method: 'GET',
      path: '/meshpad/p2p/health',
      timestampUtc: ts,
    );

    final ok = await verifySyncRequestSignature(
      peerId: 'peer-a',
      publicKeyBase64: pair.publicKeyBase64,
      timestampIso: headers[meshpadSyncTimestampHeader]!,
      method: 'GET',
      path: '/meshpad/p2p/health',
      signatureBase64: headers[meshpadSyncSignatureHeader]!,
      nowUtc: ts.add(const Duration(hours: 1)),
    );
    expect(ok, isFalse);
  });
}
