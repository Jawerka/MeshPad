import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:meshpad_server/headless_lan_sync.dart';
import 'package:meshpad_server/hub/hub_pairing_service.dart';
import 'package:meshpad_server/hub/hub_qr.dart';
import 'package:meshpad_server/hub/hub_web.dart';
import 'package:meshpad_server/meshpad_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late NoteRepository repo;
  late MeshPadDatabase db;
  late HeadlessLanSyncService lanSync;
  late HubPairingService pairing;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_hub_');
    final opened = await openRepository(dataDir: tempDir.path);
    repo = opened.repository;
    db = opened.db;
    final paths = MeshPadPaths(tempDir.path);
    final deviceStore = DeviceIdentityStore(paths: paths);
    final identity = await deviceStore.loadOrCreateIdentity(
      defaultDisplayName: 'Test Hub',
    );
    lanSync = HeadlessLanSyncService(
      repository: repo,
      deviceStore: deviceStore,
      engine: SyncEngine(notes: repo, identity: identity),
      identity: identity,
    );
    await lanSync.start();
    pairing = HubPairingService(
      lanSync: lanSync,
      deviceStore: deviceStore,
      repository: repo,
      identity: identity,
    );
    await pairing.start();
  });

  tearDown(() async {
    await pairing.dispose();
    await lanSync.dispose();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Handler hubHandler() =>
      HubWeb(pairing: pairing).buildRouter(webPort: 8787).call;

  test('GET /hub/status returns pin and qr_uri', () async {
    final response = await hubHandler()(
      Request('GET', Uri.parse('http://localhost/hub/status')),
    );
    expect(response.statusCode, 200);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['pin'], matches(r'^\d{6}$'));
    expect(body['qr_uri'], startsWith('meshpad://pair?'));
    expect(body['display_name'], 'Test Hub');
    expect(body['note_count'], isA<int>());
    expect(body.containsKey('sync_badge_kind'), isTrue);
  });

  test('POST /hub/sync returns result', () async {
    final response = await hubHandler()(
      Request('POST', Uri.parse('http://localhost/hub/sync')),
    );
    expect(response.statusCode, 200);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['result'], isA<String>());
    expect(body['status'], isA<Map<String, dynamic>>());
  });

  test('GET /hub/qr.png returns PNG bytes', () async {
    final status = await pairing.status();
    expect(status.qrUri, isNotNull);

    final response = await hubHandler()(
      Request('GET', Uri.parse('http://localhost/hub/qr.png')),
    );
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], 'image/png');
    final collected = await response.read().expand((c) => c).toList();
    expect(collected.length, greaterThan(100));
    expect(collected[0], 0x89);
    expect(collected[1], 0x50); // PNG signature
  });

  test('qrDataToPng produces decodable image', () {
    final uri = PairingQrPayload(
      host: '192.168.1.10',
      httpPort: 45838,
      pin: '123456',
      tlsPort: 45840,
    ).encode();
    final png = qrDataToPng(uri);
    expect(png.length, greaterThan(200));
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('GET / renders pairing page with hidden pairing panel', () async {
    final response = await hubHandler()(
      Request('GET', Uri.parse('http://localhost/')),
    );
    expect(response.statusCode, 200);
    final html = await response.readAsString();
    expect(html, contains('MeshPad Hub'));
    expect(html, contains('Test Hub'));
    expect(html, contains('id="show-pairing-btn"'));
    expect(html, contains('id="pairing-panel"'));
    expect(html, contains('pairing-panel" hidden'));
    expect(html, contains('id="sync-badge"'));
    expect(html, contains('Синхронизировать'));
    final actionsPos = html.indexOf('class="actions"');
    final logPos = html.indexOf('class="log"');
    expect(actionsPos, greaterThan(0));
    expect(logPos, greaterThan(actionsPos));
  });

  test('POST /hub/devices/<id>/revoke removes trusted device', () async {
    final paths = MeshPadPaths(tempDir.path);
    final store = DeviceIdentityStore(paths: paths);
    await store.trustDevice(peerId: 'peer-guest', name: 'Guest Phone');

    final response = await hubHandler()(
      Request(
        'POST',
        Uri.parse('http://localhost/hub/devices/peer-guest/revoke'),
      ),
    );
    expect(response.statusCode, 200);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['trusted_count'], 0);
    expect(await store.listTrustedDevices(), isEmpty);
  });

  test('POST /api/trash/empty permanently clears trash', () async {
    final note = await repo.createNote(title: 'trash me', markdown: 'x');
    await repo.deleteNote(note.id);
    expect((await repo.listTrash()).length, 1);

    final router = MeshPadHttpServer(
      repository: repo,
      defaultAuthor: 'test',
    ).buildRouter();
    final response = await router.call(
      Request('POST', Uri.parse('http://localhost/api/trash/empty')),
    );
    expect(response.statusCode, 200);
    final body =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(body['purged'], 1);
    expect(await repo.listTrash(), isEmpty);
  });
}
