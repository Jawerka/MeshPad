import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('UdpLanDiscovery refresh attempts constant is 3', () {
    expect(UdpLanDiscovery.refreshAttempts, 3);
  });
}
