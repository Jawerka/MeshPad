import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

void main() {
  test('payload encrypt round-trip', () async {
    const token = 'shared-auth-token';
    const local = 'peer-a';
    const remote = 'peer-b';
    const json = '{"hello":"world"}';

    final encrypted = await encryptJsonString(
      json: json,
      authToken: token,
      localPeerId: local,
      remotePeerId: remote,
    );
    expect(bodyLooksEncrypted(encrypted), isTrue);

    final decrypted = await decryptJsonString(
      body: encrypted,
      authToken: token,
      localPeerId: remote,
      remotePeerId: local,
    );
    expect(decrypted, json);
  });

  test('derivePayloadKey is symmetric for peer order', () async {
    const token = 't';
    final k1 = await derivePayloadKey(
      authToken: token,
      localPeerId: 'a',
      remotePeerId: 'b',
    );
    final k2 = await derivePayloadKey(
      authToken: token,
      localPeerId: 'b',
      remotePeerId: 'a',
    );
    final b1 = await k1.extractBytes();
    final b2 = await k2.extractBytes();
    expect(b1, b2);
  });
}
