import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';
import 'package:test/test.dart';

void main() {
  late Libp2pSidecarServer sidecar;
  late HttpServer httpServer;
  late int port;

  setUp(() async {
    sidecar = Libp2pSidecarServer(enableDiscovery: false);
    httpServer = await serveLibp2pSidecar(server: sidecar, port: 0);
    port = httpServer.port;
  });

  tearDown(() async {
    await httpServer.close(force: true);
    await sidecar.close();
  });

  test('pulls remote snapshot from sidecar wire store into SyncEngine',
      () async {
    final wire = Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:$port');
    await wire.pushSnapshot(
      snapshot: {
        'meta': {
          'schema_version': 2,
          'id': 'remote-note',
          'title': 'Remote',
          'author': 'peer',
          'created_at': '2026-06-01T10:00:00.000Z',
          'updated_at': '2026-06-01T12:00:00.000Z',
          'deleted': false,
        },
        'markdown': '# from sidecar',
      },
    );

    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);
    final repo = createNoteRepository(
      dataDir: (await Directory.systemTemp.createTemp('wire_gw_')).path,
      defaultAuthor: 'local',
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

    final gateway = SidecarWireRemoteSyncGateway(client: wire);
    final result = await engine.syncWithRemote(gateway);

    expect(result.pulled, 1);
    final note = await repo.getNote('remote-note');
    expect(note?.markdown, '# from sidecar');
  });

  test('syncWithRemote pulls note with attachment via wire gateway', () async {
    final wire = Libp2pSidecarWireClient(baseUrl: 'http://127.0.0.1:$port');
    const attachmentBytes = [9, 8, 7];
    await wire.pushSnapshot(
      snapshot: {
        'meta': {
          'schema_version': 2,
          'id': 'note-att',
          'title': 'With file',
          'author': 'peer',
          'created_at': '2026-06-01T10:00:00.000Z',
          'updated_at': '2026-06-01T12:00:00.000Z',
          'deleted': false,
          'attachments': [
            {
              'name': 'data.png',
              'size': attachmentBytes.length,
              'mime': 'application/octet-stream',
            },
          ],
        },
        'markdown': 'body',
      },
    );
    await wire.pushAttachment(
      noteId: 'note-att',
      name: 'data.png',
      bytes: attachmentBytes,
    );

    final db = MeshPadDatabase.inMemory();
    addTearDown(db.close);
    final repo = createNoteRepository(
      dataDir: (await Directory.systemTemp.createTemp('wire_att_gw_')).path,
      defaultAuthor: 'local',
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

    final result =
        await engine.syncWithRemote(SidecarWireRemoteSyncGateway(client: wire));
    expect(result.pulled, 1);

    final note = await repo.getNote('note-att');
    expect(note?.attachments, hasLength(1));
    expect(
      await repo.attachmentMatches(note!.id, note.attachments.first),
      isTrue,
    );
  });
}
