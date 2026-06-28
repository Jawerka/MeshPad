import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('requires signature when trusted peer has signing key', () async {
    final pair = await generateDeviceSigningKeyPair();
    const peerId = 'peer-remote';
    final record = TrustedDeviceRecord(
      peerId: peerId,
      name: 'Remote',
      trustedAt: DateTime.utc(2026, 1, 1),
      authToken: 'token',
      signingPublicKey: pair.publicKeyBase64,
      signingKeyAlgorithm: deviceSigningAlgorithmEd25519,
    );

    final failure = await validateLanSyncAuth(
      callerPeerId: peerId,
      authToken: 'token',
      method: 'GET',
      path: '/meshpad/p2p/catalog',
      timestampHeader: null,
      signatureHeader: null,
      lookupTrusted: (_) async => record,
    );
    expect(failure, LanSyncAuthFailure.unauthorized);
  });

  test('accepts valid token and signature', () async {
    final pair = await generateDeviceSigningKeyPair();
    const peerId = 'peer-remote';
    const path = '/meshpad/p2p/catalog';
    final ts = DateTime.utc(2026, 6, 1, 12);
    final headers = await syncSignatureHeaders(
      peerId: peerId,
      privateKeyBytes: pair.privateKeyBytes,
      method: 'GET',
      path: path,
      timestampUtc: ts,
    );

    final record = TrustedDeviceRecord(
      peerId: peerId,
      name: 'Remote',
      trustedAt: DateTime.utc(2026, 1, 1),
      authToken: 'token',
      signingPublicKey: pair.publicKeyBase64,
      signingKeyAlgorithm: deviceSigningAlgorithmEd25519,
    );

    final failure = await validateLanSyncAuth(
      callerPeerId: peerId,
      authToken: 'token',
      method: 'GET',
      path: path,
      timestampHeader: headers[meshpadSyncTimestampHeader],
      signatureHeader: headers[meshpadSyncSignatureHeader],
      lookupTrusted: (_) async => record,
      nowUtc: ts,
    );
    expect(failure, isNull);
  });

  test('legacy peer without signing key needs token only', () async {
    final record = TrustedDeviceRecord(
      peerId: 'legacy',
      name: 'Legacy',
      trustedAt: DateTime.utc(2026, 1, 1),
      authToken: 'token',
    );

    final failure = await validateLanSyncAuth(
      callerPeerId: 'legacy',
      authToken: 'token',
      method: 'GET',
      path: '/meshpad/p2p/catalog',
      timestampHeader: null,
      signatureHeader: null,
      lookupTrusted: (_) async => record,
    );
    expect(failure, isNull);
  });
}
