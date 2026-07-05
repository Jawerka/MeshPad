import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('CascadeSyncRequest.fromWire merges legacy excludePeerId', () {
    final request = CascadeSyncRequest.fromWire({
      'excludePeerId': 'peer-a',
      'excludePeerIds': ['peer-b'],
      'hopLimit': 4,
    });

    expect(request.excludePeerIds, ['peer-a', 'peer-b']);
    expect(request.hopLimit, 4);
  });

  test('CascadeSyncRequest.toWire includes legacy excludePeerId', () {
    final wire = const CascadeSyncRequest(
      excludePeerIds: ['peer-a'],
      hopLimit: 2,
    ).toWire();

    expect(wire['excludePeerIds'], ['peer-a']);
    expect(wire['excludePeerId'], 'peer-a');
    expect(wire['hopLimit'], 2);
  });
}
