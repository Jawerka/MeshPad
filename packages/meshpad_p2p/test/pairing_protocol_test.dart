import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('pairing pin helpers', () {
    final pin = generatePairingPin();
    expect(isValidPairingPin(pin), isTrue);
    expect(isValidPairingPin('12345'), isFalse);

    final offer = PinPairingOffer(
      peerId: 'peer-1',
      displayName: 'Phone',
      pin: pin,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
    final json = offer.toJson();
    expect(PinPairingOffer.fromJson(json).peerId, 'peer-1');
  });
}
