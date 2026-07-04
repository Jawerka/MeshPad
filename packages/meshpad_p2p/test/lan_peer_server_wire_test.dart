import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:test/test.dart';

void main() {
  test('PUT note with invalid JSON returns 400', () async {
    final dir = await Directory.systemTemp.createTemp('lan_server_wire_');
    final db = MeshPadDatabase.inMemory();
    addTearDown(() async {
      await db.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final repo = createNoteRepository(
      dataDir: dir.path,
      defaultAuthor: 'test',
      database: db,
    );
    final engine = SyncEngine(
      notes: repo,
      identity: LocalDeviceIdentity(
        peerId: 'local',
        displayName: 'Local',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final server = LanPeerServer(
      preferredPort: 0,
      getEngine: () async => engine,
    );
    final port = await server.start();
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(client.close);

    final request = await client.put(
      '127.0.0.1',
      port,
      '/meshpad/p2p/notes/note-1',
    );
    request.headers.contentType = ContentType.json;
    request.write('not-json');
    final response = await request.close();
    expect(response.statusCode, 400);
  });

  test('pairing confirm with invalid JSON returns 400', () async {
    final dir = await Directory.systemTemp.createTemp('lan_server_pair_');
    final db = MeshPadDatabase.inMemory();
    addTearDown(() async {
      await db.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final repo = createNoteRepository(
      dataDir: dir.path,
      defaultAuthor: 'test',
      database: db,
    );
    final engine = SyncEngine(
      notes: repo,
      identity: LocalDeviceIdentity(
        peerId: 'local',
        displayName: 'Local',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );

    final server = LanPeerServer(
      preferredPort: 0,
      getEngine: () async => engine,
    );
    final port = await server.start();
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(client.close);

    final request = await client.post(
      '127.0.0.1',
      port,
      '/meshpad/p2p/pairing/confirm',
    );
    request.headers.contentType = ContentType.json;
    request.write('{bad');
    final response = await request.close();
    expect(response.statusCode, 400);
  });
}
