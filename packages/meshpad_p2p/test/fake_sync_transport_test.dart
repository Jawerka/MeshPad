import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('FakeSyncTransport completes sync', () async {
    final transport = FakeSyncTransport();
    await transport.start();

    final future = transport.events.first;
    await transport.requestSync();
    final event = await future;

    expect(event, isA<SyncCompleted>());
    transport.dispose();
  });
}
