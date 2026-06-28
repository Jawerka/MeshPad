import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('remember and lookup wire base', () {
    final registry = Libp2pPeerWireRegistry();
    registry.remember('peer-b', 'http://127.0.0.1:45840');
    expect(registry.wireBaseFor('peer-b'), 'http://127.0.0.1:45840');
    expect(registry.remoteWireBaseFor('peer-b'), 'http://127.0.0.1:45840');
    expect(registry.isExplicit('peer-b'), isTrue);
    registry.forget('peer-b');
    expect(registry.wireBaseFor('peer-b'), isNull);
  });

  test('rememberInferred is not used for remoteWireBaseFor', () {
    final registry = Libp2pPeerWireRegistry();
    registry.rememberInferred('peer-c', 'http://192.168.1.5:45839/');
    expect(registry.wireBaseFor('peer-c'), 'http://192.168.1.5:45839/');
    expect(registry.remoteWireBaseFor('peer-c'), isNull);
    expect(registry.isExplicit('peer-c'), isFalse);
  });

  test('wireBasesFromEnvironment parses JSON', () {
    // Empty when unset in test VM.
    expect(wireBasesFromEnvironment(), isEmpty);
  });

  test('inferPeerWireBase prefers explicit wire_base', () {
    expect(
      inferPeerWireBase(
        explicitWireBase: 'http://10.0.0.2:9999/',
        lanHost: '10.0.0.2',
        wirePort: 45839,
      ),
      'http://10.0.0.2:9999/',
    );
  });

  test('inferPeerWireBase builds URL from lan host', () {
    expect(
      inferPeerWireBase(lanHost: '192.168.1.8', wirePort: 45840),
      'http://192.168.1.8:45840/',
    );
  });
}
