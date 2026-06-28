import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_p2p/src/lan/lan_catalog_body.dart';
import 'package:test/test.dart';

void main() {
  test('encodeLanCatalogBody gzip when large enough', () {
    final heads = List.generate(
      40,
      (i) => NoteHead(
        id: 'id-$i',
        updatedAt: DateTime.utc(2026, 5, 1, 12, 0, i),
        deleted: false,
      ),
    );
    final plain = encodeLanCatalogBody(heads, useGzip: false);
    final compressed = encodeLanCatalogBody(heads, useGzip: true);
    expect(plain.gzipped, isFalse);
    expect(compressed.gzipped, isTrue);
    expect(compressed.bytes.length, lessThan(plain.bytes.length));
    final decoded = decodeLanCatalogBody(compressed.bytes, gzipped: true);
    expect(decoded.map((h) => h.id), heads.map((h) => h.id));
  });

  test('LAN catalog GET negotiates gzip', () async {
    final dir = await Directory.systemTemp.createTemp('meshpad_gzip_');
    final db = MeshPadDatabase.inMemory();
    final repo = createNoteRepository(
      dataDir: dir.path,
      defaultAuthor: 'peer-a',
      database: db,
    );
    final engine = SyncEngine(
      notes: repo,
      identity: LocalDeviceIdentity(
        peerId: 'peer-a',
        displayName: 'A',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final store = DeviceIdentityStore(paths: MeshPadPaths(dir.path));
    final token = generateSyncAuthToken();
    await store.trustDevice(
      peerId: 'peer-b',
      name: 'B',
      authToken: token,
    );
    for (var i = 0; i < 50; i++) {
      await repo.createNote(markdown: 'note $i with padding text');
    }

    final server = LanPeerServer(
      preferredPort: 0,
      getEngine: () async => engine,
      lookupTrustedPeer: store.trustedRecordFor,
    );
    final port = await server.start();
    addTearDown(() async {
      await server.stop();
      await db.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/meshpad/p2p/catalog'),
      );
      request.headers.set(meshpadSyncPeerIdHeader, 'peer-b');
      request.headers.set(meshpadSyncAuthTokenHeader, token);
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(response.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
      final body = await response.fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      final heads = noteHeadsFromJsonList(
        jsonDecode(utf8.decode(body)) as List<dynamic>,
      );
      expect(heads.length, 50);
    } finally {
      client.close(force: true);
    }

    final gateway = HttpRemoteSyncGateway(
      endpoint: LanPeerEndpoint(
        peerId: 'peer-a',
        displayName: 'A',
        host: '127.0.0.1',
        httpPort: port,
      ),
      callerPeerId: 'peer-b',
      authToken: token,
    );
    final viaGateway = await gateway.fetchCatalog();
    expect(viaGateway.length, 50);
  });
}
