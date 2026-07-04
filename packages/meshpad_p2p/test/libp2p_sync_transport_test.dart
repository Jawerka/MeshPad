import 'dart:async';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

class _FakeNativeApi implements Libp2pNativeApi {
  _FakeNativeApi(this._events);

  final StreamController<Libp2pNativeEvent> _events;
  var syncCalls = 0;
  String? lastSyncPeerId;

  @override
  Stream<Libp2pNativeEvent> get events => _events.stream;

  @override
  Future<void> requestSync({String? peerId, String? remoteWireBase}) async {
    syncCalls++;
    lastSyncPeerId = peerId;
  }

  @override
  Future<void> start({
    required String peerId,
    required String displayName,
  }) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  test('Libp2pSyncTransport exposes LAN fallback via lanAccess', () {
    Future<SyncEngine> getEngine() async => throw UnimplementedError();
    Future<LocalDeviceIdentity> getIdentity() async =>
        throw UnimplementedError();

    final transport = Libp2pSyncTransport(
      getEngine: getEngine,
      getIdentity: getIdentity,
    );

    expect(transport.lanFallback, isA<LanSyncTransport>());
    expect((transport as SyncTransport).lanAccess, same(transport.lanFallback));
  });

  test('Libp2pSyncTransport caches LAN endpoint from native discovery',
      () async {
    final events = StreamController<Libp2pNativeEvent>.broadcast();
    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);

    final repo = createNoteRepository(
      dataDir: (await Directory.systemTemp.createTemp('libp2p_')).path,
      defaultAuthor: 'local',
      database: db,
    );
    final identity = LocalDeviceIdentity(
      peerId: 'local',
      displayName: 'Local',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final engine = SyncEngine(notes: repo, identity: identity);

    final transport = Libp2pSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      nativeApi: _FakeNativeApi(events),
      trySidecar: false,
    );

    await transport.start();

    final nextEvent = transport.events.first;
    events.add(
      Libp2pNativePeerDiscovered(
        peerId: 'remote',
        displayName: 'Remote',
        lanHost: '10.0.0.2',
        httpPort: 45838,
        tlsPort: 45840,
      ),
    );

    final discovered = await nextEvent;
    expect(discovered, isA<PeerDiscovered>());

    final endpoint = transport.endpointFor('remote');
    expect(endpoint, isNotNull);
    expect(endpoint!.host, '10.0.0.2');
    expect(endpoint.httpPort, 45838);
    expect(endpoint.tlsPort, 45840);

    await transport.stop();
    transport.dispose();
    await events.close();
  });

  test('Libp2pSyncTransport requestSync pings native sidecar', () async {
    final events = StreamController<Libp2pNativeEvent>.broadcast();
    final native = _FakeNativeApi(events);
    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);

    final repo = createNoteRepository(
      dataDir: (await Directory.systemTemp.createTemp('libp2p_sync_')).path,
      defaultAuthor: 'local',
      database: db,
    );
    final identity = LocalDeviceIdentity(
      peerId: 'local',
      displayName: 'Local',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final engine = SyncEngine(notes: repo, identity: identity);

    final transport = Libp2pSyncTransport(
      getEngine: () async => engine,
      getIdentity: () async => identity,
      nativeApi: native,
      trySidecar: false,
    );

    await transport.start();
    await transport.requestSync(peerId: 'remote-peer');
    expect(native.syncCalls, 1);
    expect(native.lastSyncPeerId, 'remote-peer');

    await transport.stop();
    transport.dispose();
    await events.close();
  });
}
