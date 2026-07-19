import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

Future<
    ({
      Directory dirA,
      Directory dirB,
      MeshPadDatabase dbA,
      MeshPadDatabase dbB,
      DeviceIdentityStore storeA,
      DeviceIdentityStore storeB,
      SyncEngine engineA,
      SyncEngine engineB,
      NoteRepository repoA,
      NoteRepository repoB,
      LanPeerServer serverA,
      LanPeerServer serverB,
      int portA,
      int portB,
      String sharedToken,
    })> _pairingTestHarness() async {
  final dirA = await Directory.systemTemp.createTemp('lan_a_');
  final dirB = await Directory.systemTemp.createTemp('lan_b_');
  final dbA = MeshPadDatabase.inMemory();
  final dbB = MeshPadDatabase.inMemory();

  final storeA = DeviceIdentityStore(paths: MeshPadPaths(dirA.path));
  final storeB = DeviceIdentityStore(paths: MeshPadPaths(dirB.path));
  final sharedToken = generateSyncAuthToken();

  await storeA.trustDevice(
    peerId: 'peer-b',
    name: 'B',
    authToken: sharedToken,
  );
  await storeB.trustDevice(
    peerId: 'peer-a',
    name: 'A',
    authToken: sharedToken,
  );

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

  final serverA = LanPeerServer(
    preferredPort: 0,
    getEngine: () async => engineA,
    lookupTrustedPeer: storeA.trustedRecordFor,
  );
  final serverB = LanPeerServer(
    preferredPort: 0,
    getEngine: () async => engineB,
    lookupTrustedPeer: storeB.trustedRecordFor,
  );
  final portA = await serverA.start();
  final portB = await serverB.start();

  return (
    dirA: dirA,
    dirB: dirB,
    dbA: dbA,
    dbB: dbB,
    storeA: storeA,
    storeB: storeB,
    engineA: engineA,
    engineB: engineB,
    repoA: repoA,
    repoB: repoB,
    serverA: serverA,
    serverB: serverB,
    portA: portA,
    portB: portB,
    sharedToken: sharedToken,
  );
}

void main() {
  test('LAN HTTP sync exchanges notes between two peers', () async {
    final harness = await _pairingTestHarness();
    addTearDown(() async {
      await harness.dbA.close();
      await harness.dbB.close();
      await harness.serverA.stop();
      await harness.serverB.stop();
      if (await harness.dirA.exists()) {
        await harness.dirA.delete(recursive: true);
      }
      if (await harness.dirB.exists()) {
        await harness.dirB.delete(recursive: true);
      }
    });

    await harness.repoA.createNote(markdown: 'from A');
    await harness.repoB.createNote(markdown: 'from B');

    final attachmentSource = File('${harness.dirA.path}/photo.png');
    await attachmentSource
        .writeAsBytes(List<int>.generate(128, (i) => i % 256));
    final noteWithFile = await harness.repoA.createNote(
      markdown: 'note with file',
      attachmentPaths: [attachmentSource.path],
    );

    final host = InternetAddress.loopbackIPv4.address;
    final gatewayB = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-b',
        displayName: 'B',
        host: host,
        httpPort: harness.portB,
      ),
      callerPeerId: 'peer-a',
      authToken: harness.sharedToken,
    );
    final gatewayA = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-a',
        displayName: 'A',
        host: host,
        httpPort: harness.portA,
      ),
      callerPeerId: 'peer-b',
      authToken: harness.sharedToken,
    );

    final resultA = await harness.engineA.syncWithRemote(gatewayB);
    final resultB = await harness.engineB.syncWithRemote(gatewayA);

    expect((await harness.repoA.listNotes()).length, 3);
    expect((await harness.repoB.listNotes()).length, 3);
    expect(resultA.total + resultB.total, greaterThan(0));

    final synced = await harness.repoB.getNote(noteWithFile.id);
    expect(synced?.attachments.length, 1);
    expect(
      await harness.repoB
          .attachmentMatches(synced!.id, synced.attachments.first),
      isTrue,
    );
  });

  test('sync without auth token returns 401 when auth is configured', () async {
    final harness = await _pairingTestHarness();
    addTearDown(() async {
      await harness.dbA.close();
      await harness.dbB.close();
      await harness.serverA.stop();
      await harness.serverB.stop();
      if (await harness.dirA.exists()) {
        await harness.dirA.delete(recursive: true);
      }
      if (await harness.dirB.exists()) {
        await harness.dirB.delete(recursive: true);
      }
    });

    final gateway = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-b',
        displayName: 'B',
        host: InternetAddress.loopbackIPv4.address,
        httpPort: harness.portB,
      ),
    );

    expect(
      () => gateway.fetchCatalog(),
      throwsA(isA<HttpRemoteSyncException>()
          .having((e) => e.statusCode, 'code', 401)),
    );
  });

  test('sync with wrong auth token returns 401 token body', () async {
    final harness = await _pairingTestHarness();
    addTearDown(() async {
      await harness.dbA.close();
      await harness.dbB.close();
      await harness.serverA.stop();
      await harness.serverB.stop();
      if (await harness.dirA.exists()) {
        await harness.dirA.delete(recursive: true);
      }
      if (await harness.dirB.exists()) {
        await harness.dirB.delete(recursive: true);
      }
    });

    final gateway = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-b',
        displayName: 'B',
        host: InternetAddress.loopbackIPv4.address,
        httpPort: harness.portB,
      ),
      callerPeerId: 'peer-a',
      authToken: 'wrong-token',
    );

    expect(
      () => gateway.fetchCatalog(),
      throwsA(
        isA<HttpRemoteSyncException>()
            .having((e) => e.statusCode, 'code', 401)
            .having((e) => e.body, 'body', 'unauthorized:token'),
      ),
    );
  });

  test('401 auth failure keeps transport peer cache for re-pair', () async {
    final harness = await _pairingTestHarness();
    addTearDown(() async {
      await harness.dbA.close();
      await harness.dbB.close();
      await harness.serverA.stop();
      await harness.serverB.stop();
      if (await harness.dirA.exists()) {
        await harness.dirA.delete(recursive: true);
      }
      if (await harness.dirB.exists()) {
        await harness.dirB.delete(recursive: true);
      }
    });

    final host = InternetAddress.loopbackIPv4.address;
    final transport = LanSyncTransport(
      getEngine: () async => harness.engineA,
      getIdentity: () async => harness.engineA.identity,
      getDeviceStore: () async => harness.storeA,
    );
    await transport.start();
    addTearDown(transport.dispose);

    transport.rememberEndpoint(
      LanPeerEndpoint(
        peerId: 'peer-b',
        displayName: 'B',
        host: host,
        httpPort: harness.portB,
      ),
    );
    expect(transport.endpointFor('peer-b'), isNotNull);

    await harness.storeA.trustDevice(
      peerId: 'peer-b',
      name: 'B',
      authToken: 'wrong-token',
    );

    await transport.requestSync(peerId: 'peer-b');
    expect(transport.endpointFor('peer-b'), isNotNull);
    expect(await harness.storeA.trustedRecordFor('peer-b'), isNotNull);
  });

  test('sync from untrusted peer returns 403', () async {
    final harness = await _pairingTestHarness();
    addTearDown(() async {
      await harness.dbA.close();
      await harness.dbB.close();
      await harness.serverA.stop();
      await harness.serverB.stop();
      if (await harness.dirA.exists()) {
        await harness.dirA.delete(recursive: true);
      }
      if (await harness.dirB.exists()) {
        await harness.dirB.delete(recursive: true);
      }
    });

    final gateway = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-b',
        displayName: 'B',
        host: InternetAddress.loopbackIPv4.address,
        httpPort: harness.portB,
      ),
      callerPeerId: 'peer-unknown',
      authToken: harness.sharedToken,
    );

    expect(
      () => gateway.fetchCatalog(),
      throwsA(isA<HttpRemoteSyncException>()
          .having((e) => e.statusCode, 'code', 403)),
    );
  });

  test('PIN pairing confirm over LAN HTTP without auth headers', () async {
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

    final server = LanPeerServer(
      preferredPort: 0,
      getEngine: () async => engine,
      lookupTrustedPeer: (_) async => null,
    );
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
      PinPairingConfirm(
        peerId: 'peer-x',
        pin: '123456',
        initiatorPeerId: 'peer-y',
        initiatorDisplayName: 'Y',
        initiatorLanHost: '127.0.0.1',
        initiatorHttpPort: 45839,
        authToken: generateSyncAuthToken(),
      ),
    );
    expect(ok, isTrue);

    await server.stop();
  });

  test('pairing confirm rate limit returns 429', () async {
    final dir = await Directory.systemTemp.createTemp('lan_rate_');
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

    final limiter = PairingConfirmRateLimiter(maxAttempts: 2);
    final server = LanPeerServer(
      preferredPort: 0,
      getEngine: () async => engine,
      pairingRateLimiter: limiter,
    );
    final port = await server.start();
    server.setPairingOffer(
      createPairingOffer(
        peerId: 'peer-x',
        displayName: 'X',
        pin: '123456',
      ),
    );

    final endpoint = LanPeerEndpoint(
      peerId: 'peer-x',
      displayName: 'X',
      host: InternetAddress.loopbackIPv4.address,
      httpPort: port,
    );
    final gateway = HttpRemoteSyncGateway(endpoint: endpoint);

    const badConfirm = PinPairingConfirm(
      peerId: 'peer-x',
      pin: '000000',
      initiatorPeerId: 'peer-y',
    );

    expect(await gateway.confirmPairing(badConfirm), isFalse);
    expect(await gateway.confirmPairing(badConfirm), isFalse);
    expect(await gateway.confirmPairing(badConfirm), isFalse);

    await server.stop();
  });

  test('chunked resumable attachment upload over LAN HTTP', () async {
    final harness = await _pairingTestHarness();
    addTearDown(() async {
      await harness.dbA.close();
      await harness.dbB.close();
      await harness.serverA.stop();
      await harness.serverB.stop();
      if (await harness.dirA.exists()) {
        await harness.dirA.delete(recursive: true);
      }
      if (await harness.dirB.exists()) {
        await harness.dirB.delete(recursive: true);
      }
    });

    final largeBytes = List<int>.generate(300 * 1024, (i) => i % 251);
    final attachmentSource = File('${harness.dirA.path}/large.png');
    await attachmentSource.writeAsBytes(largeBytes);
    final noteWithFile = await harness.repoA.createNote(
      markdown: 'large attachment',
      attachmentPaths: [attachmentSource.path],
    );

    final gatewayB = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-b',
        displayName: 'B',
        host: InternetAddress.loopbackIPv4.address,
        httpPort: harness.portB,
      ),
      callerPeerId: 'peer-a',
      authToken: harness.sharedToken,
    );

    await harness.engineA.syncWithRemote(gatewayB);

    final synced = await harness.repoB.getNote(noteWithFile.id);
    expect(synced?.attachments.length, 1);
    expect(
      await harness.repoB
          .attachmentMatches(synced!.id, synced.attachments.first),
      isTrue,
    );
  });
}
