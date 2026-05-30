import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/theme/device_icons.dart';

void main() {
  test('peerAccentColor is stable for same peer id', () {
    expect(peerAccentColor('peer-a'), peerAccentColor('peer-a'));
    expect(peerAccentColor('peer-a'), isNot(peerAccentColor('peer-b')));
  });
}
