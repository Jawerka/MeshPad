import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

import 'rust_sidecar_harness.dart';

/// PLAN 8.3 E2E: two Rust sidecar processes (skipped when `cargo` / binary unavailable).
Future<void> main() async {
  final harness = await RustSidecarHarness.tryCreate();
  if (harness == null) {
    test(
      'two Rust sidecars replicate via remote_wire_base and Libp2pSyncTransport',
      () {},
      skip: 'Rust sidecar not built (install Rust and run cargo build)',
    );
    return;
  }

  test(
    'two Rust sidecars replicate via remote_wire_base and Libp2pSyncTransport',
    () async {
      final portA = await RustSidecarHarness.findFreePort();
      final portB = await RustSidecarHarness.findFreePort();
      final baseA = 'http://127.0.0.1:$portA';
      final baseB = 'http://127.0.0.1:$portB';

      final procA = await harness.start(port: portA);
      final procB = await harness.start(port: portB);
      addTearDown(() async {
        await RustSidecarHarness.stopProcess(procA);
        await RustSidecarHarness.stopProcess(procB);
      });

      await RustSidecarHarness.waitForHealth(baseA);
      await RustSidecarHarness.waitForHealth(baseB);

      final apiA = HttpLibp2pNativeApi(baseUrl: baseA);
      final health = await apiA.fetchHealth();
      expect(health?.isRustLibp2p, isTrue);

      final wireB = Libp2pSidecarWireClient(baseUrl: baseB);
      await wireB.pushSnapshot(
        snapshot: {
          'meta': {
            'schema_version': 2,
            'id': 'rust-dart-e2e',
            'title': 'B',
            'author': 'peer-b',
            'created_at': '2026-06-01T08:00:00.000Z',
            'updated_at': '2026-06-01T09:00:00.000Z',
            'deleted': false,
          },
          'markdown': '# from rust B',
        },
      );

      final db = MeshPadDatabase.inMemory();
      addTearDown(db.close);
      final repo = createNoteRepository(
        dataDir: (await Directory.systemTemp.createTemp('rust_e2e_')).path,
        defaultAuthor: 'peer-a',
        database: db,
      );
      final identity = LocalDeviceIdentity(
        peerId: 'peer-a',
        displayName: 'A',
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final engine = SyncEngine(notes: repo, identity: identity);

      final transport = Libp2pSyncTransport(
        getEngine: () async => engine,
        getIdentity: () async => identity,
        nativeApi: apiA,
        trySidecar: false,
      );

      await transport.start(startLanStack: false);
      addTearDown(() async {
        await transport.stop();
        transport.dispose();
      });

      transport.rememberPeerWireBase('peer-b', '$baseB/');

      await transport.requestSync(peerId: 'peer-b');

      final note = await repo.getNote('rust-dart-e2e');
      expect(note?.markdown, '# from rust B');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
