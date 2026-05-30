import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('LAN HTTP sync exchanges notes between two peers', () async {
    final dirA = await Directory.systemTemp.createTemp('lan_a_');
    final dirB = await Directory.systemTemp.createTemp('lan_b_');
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

    final serverA = LanPeerServer(getEngine: () async => engineA);
    final serverB = LanPeerServer(getEngine: () async => engineB);
    final portA = await serverA.start();
    final portB = await serverB.start();

    await repoA.createNote(markdown: 'from A');
    await repoB.createNote(markdown: 'from B');

    final attachmentSource = File('${dirA.path}/photo.bin');
    await attachmentSource.writeAsBytes(List<int>.generate(128, (i) => i % 256));
    final noteWithFile = await repoA.createNote(
      markdown: 'note with file',
      attachmentPaths: [attachmentSource.path],
    );

    final gatewayB = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-b',
        displayName: 'B',
        host: InternetAddress.loopbackIPv4.address,
        httpPort: portB,
      ),
    );
    final gatewayA = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-a',
        displayName: 'A',
        host: InternetAddress.loopbackIPv4.address,
        httpPort: portA,
      ),
    );

    final resultA = await engineA.syncWithRemote(gatewayB);
    final resultB = await engineB.syncWithRemote(gatewayA);

    expect((await repoA.listNotes()).length, 3);
    expect((await repoB.listNotes()).length, 3);
    expect(resultA.total + resultB.total, greaterThan(0));

    final synced = await repoB.getNote(noteWithFile.id);
    expect(synced?.attachments.length, 1);
    expect(
      await repoB.attachmentMatches(synced!.id, synced.attachments.first),
      isTrue,
    );

    await serverA.stop();
    await serverB.stop();
  });

  test('PIN pairing confirm over LAN HTTP', () async {
    final dir = await Directory.systemTemp.createTemp('lan_pair_');
    final db = MeshPadDatabase.inMemory();
    addTearDown(() async {
      await db.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final repo = createNoteRepository(
      dataDir: dir.path,
      defaultAuthor: 'x',
      database: db,
    );
    final engine = SyncEngine(
      notes: repo,
      identity: LocalDeviceIdentity(
        peerId: 'peer-x',
        displayName: 'X',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final server = LanPeerServer(getEngine: () async => engine);
    final port = await server.start();
    server.setPairingOffer(
      PinPairingOffer(
        peerId: 'peer-x',
        displayName: 'X',
        pin: '123456',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ),
    );

    final gateway = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-x',
        displayName: 'X',
        host: InternetAddress.loopbackIPv4.address,
        httpPort: port,
      ),
    );

    final ok = await gateway.confirmPairing(
      const PinPairingConfirm(peerId: 'peer-x', pin: '123456'),
    );
    expect(ok, isTrue);

    await server.stop();
  });
}
