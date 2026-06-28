import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('encode and decode round-trip', () {
    const payload = PairingQrPayload(
      host: '192.168.1.42',
      httpPort: 45838,
      pin: '123456',
      tlsPort: 45840,
    );
    final raw = payload.encode();
    expect(raw, contains('meshpad://pair'));
    expect(raw, contains('host=192.168.1.42'));

    final decoded = PairingQrPayload.decode(raw);
    expect(decoded.host, '192.168.1.42');
    expect(decoded.httpPort, 45838);
    expect(decoded.pin, '123456');
    expect(decoded.tlsPort, 45840);
  });

  test('tryDecode rejects invalid pin', () {
    final raw = PairingQrPayload(
      host: '10.0.0.1',
      httpPort: 45838,
      pin: '123456',
    ).encode().replaceFirst('pin=123456', 'pin=12');
    expect(PairingQrPayload.tryDecode(raw), isNull);
  });
}
