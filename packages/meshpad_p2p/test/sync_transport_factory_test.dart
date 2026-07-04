import 'package:meshpad_core/meshpad_core.dart';
import 'package:test/test.dart';

import 'package:meshpad_p2p/meshpad_p2p.dart';

void main() {
  group('createSyncTransport', () {
    Future<SyncEngine> getEngine() async => throw UnimplementedError();
    Future<LocalDeviceIdentity> getIdentity() async =>
        throw UnimplementedError();

    test('lan kind returns LanSyncTransport', () {
      final transport = createSyncTransport(
        kind: SyncTransportKind.lan,
        getEngine: getEngine,
        getIdentity: getIdentity,
      );
      expect(transport, isA<LanSyncTransport>());
    });

    test('libp2p kind maps to LanSyncTransport (ADR 0003)', () {
      final transport = createSyncTransport(
        kind: SyncTransportKind.libp2p,
        getEngine: getEngine,
        getIdentity: getIdentity,
      );
      expect(transport, isA<LanSyncTransport>());
    });
  });

  group('syncTransportKind wire', () {
    test('round-trip', () {
      expect(syncTransportKindFromWire(null), SyncTransportKind.lan);
      expect(syncTransportKindFromWire('lan'), SyncTransportKind.lan);
      expect(syncTransportKindFromWire('libp2p'), SyncTransportKind.lan);
      expect(syncTransportKindToWire(SyncTransportKind.lan), 'lan');
      expect(syncTransportKindToWire(SyncTransportKind.libp2p), 'libp2p');
    });
  });
}
