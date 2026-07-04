import 'package:test/test.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

void main() {
  test('gentle profile uses slower discovery intervals', () {
    final gentle = LanNetworkProfileSettings.forProfile(
      LanNetworkProfile.gentle,
    );
    final normal = LanNetworkProfileSettings.forProfile(
      LanNetworkProfile.normal,
    );

    expect(gentle.mdnsBrowseInterval > normal.mdnsBrowseInterval, isTrue);
    expect(gentle.udpAnnounceInterval > normal.udpAnnounceInterval, isTrue);
    expect(gentle.propagateCascade, isFalse);
    expect(normal.propagateCascade, isTrue);
  });
}
