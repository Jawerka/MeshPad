import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('FakeSyncHub syncs two registered peers', () async {
    final dirA = await Directory.systemTemp.createTemp('hub_a_');
    final dirB = await Directory.systemTemp.createTemp('hub_b_');
    final dbA = MeshPadDatabase.inMemory();
    final dbB = MeshPadDatabase.inMemory();

    addTearDown(() async {
      await dbA.close();
      await dbB.close();
      if (await dirA.exists()) await dirA.delete(recursive: true);
      if (await dirB.exists()) await dirB.delete(recursive: true);
    });

    final repoA = createNoteRepository(
      dataDir: dirA.path,
      defaultAuthor: 'a',
      database: dbA,
    );
    final repoB = createNoteRepository(
      dataDir: dirB.path,
      defaultAuthor: 'b',
      database: dbB,
    );

    final engineA = SyncEngine(
      notes: repoA,
      identity: LocalDeviceIdentity(
        peerId: 'peer-a',
        displayName: 'A',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final engineB = SyncEngine(
      notes: repoB,
      identity: LocalDeviceIdentity(
        peerId: 'peer-b',
        displayName: 'B',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final hub = FakeSyncHub()
      ..register('peer-a', engineA)
      ..register('peer-b', engineB);

    await repoA.createNote(markdown: 'via hub');

    final transport = FakeSyncTransport(
      hub: hub,
      localPeerId: 'peer-a',
      remotePeerId: 'peer-b',
    );
    await transport.start();

    final future = transport.events.first;
    await transport.requestSync();
    final event = await future;

    expect(event, isA<SyncCompleted>());
    expect((event as SyncCompleted).noteCount, 1);
    expect((await repoB.listNotes()).length, 1);

    transport.dispose();
  });
}
