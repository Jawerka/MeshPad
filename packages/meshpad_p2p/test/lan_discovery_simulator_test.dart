import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('LanDiscoverySimulator emits demo peers', () async {
    final transport = FakeSyncTransport();
    final simulator = LanDiscoverySimulator(
      transport,
      initialDelay: Duration.zero,
    );

    final events = <PeerDiscovered>[];
    final sub = transport.events.listen((event) {
      if (event is PeerDiscovered) events.add(event);
    });

    await transport.start();
    simulator.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(events.length, LanDiscoverySimulator.demoPeers.length);
    await sub.cancel();
    simulator.dispose();
    transport.dispose();
  });
}
