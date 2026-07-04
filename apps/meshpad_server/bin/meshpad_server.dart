import 'dart:async';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_server/headless_lan_sync.dart';
import 'package:meshpad_server/api_key_auth.dart';
import 'package:meshpad_server/hub/hub_pairing_service.dart';
import 'package:meshpad_server/hub/hub_web.dart';
import 'package:meshpad_server/meshpad_server.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:shelf/shelf.dart';

Future<void> main(List<String> args) async {
  var dataDir = './var/meshpad';
  var host = InternetAddress.loopbackIPv4.address;
  var port = 8787;
  var hubMode = false;
  var p2pEnabled = false;
  var syncIntervalMinutes = 15;
  String? apiKey;
  String hubDisplayName = 'MeshPad Hub';

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--data-dir':
        if (i + 1 < args.length) dataDir = args[++i];
      case '--host':
        if (i + 1 < args.length) host = args[++i];
      case '--port':
        if (i + 1 < args.length) port = int.parse(args[++i]);
      case '--hub':
        hubMode = true;
      case '--p2p':
        p2pEnabled = true;
      case '--sync-interval':
        if (i + 1 < args.length) {
          syncIntervalMinutes = int.parse(args[++i]);
        }
      case '--api-key':
        if (i + 1 < args.length) apiKey = args[++i];
      case '--name':
        if (i + 1 < args.length) hubDisplayName = args[++i];
      case '--help':
      case '-h':
        stdout.writeln('''
MeshPad headless HTTP server

Usage:
  dart run meshpad_server [--hub] [--data-dir PATH] [--host HOST] [--port PORT]
                          [--p2p] [--sync-interval MINUTES] [--api-key KEY]
                          [--name DISPLAY_NAME]

Options:
  --hub              LAN hub mode: web PIN/QR page + always-on P2P sync
  --p2p              Enable LAN P2P sync (UDP discovery + HTTP) with trusted peers
  --sync-interval    Auto-sync interval in minutes when P2P is enabled (default: 15, hub: 5)
  --api-key          Require API key on /api/* (except /api/health). Env: MESHPAD_API_KEY
  --name             Hub display name (hub mode only)

Hub mode:
  GET  /                 PIN + QR pairing page
  GET  /hub/status       JSON hub status
  POST /hub/pairing/refresh  Regenerate PIN

API endpoints:
  GET  /api/health
  GET  /api/notes
  GET  /api/notes/<id>
  GET  /api/events   (SSE feed updates)
  POST /api/notes  {"markdown":"...", "title":"", "author":""}
  PUT  /api/notes/<id>/attachments/<name>  (octet-stream)
  GET  /api/notes/<id>/attachments/<name>/thumb  (JPEG preview)
''');
        return;
    }
  }

  if (hubMode) {
    p2pEnabled = true;
    if (host == InternetAddress.loopbackIPv4.address) {
      host = InternetAddress.anyIPv4.address;
    }
    if (syncIntervalMinutes == 15) {
      syncIntervalMinutes = 5;
    }
  }

  apiKey ??= Platform.environment['MESHPAD_API_KEY'];
  hubDisplayName =
      Platform.environment['MESHPAD_HUB_NAME'] ?? hubDisplayName;

  final opened = await openRepository(dataDir: dataDir);
  final auth = ApiKeyAuth(apiKey: apiKey);
  final httpServer = MeshPadHttpServer(
    repository: opened.repository,
    defaultAuthor: hubMode ? hubDisplayName : 'MeshPad Server',
    apiKeyAuth: auth,
  );

  HeadlessLanSyncService? lanSync;
  HubPairingService? hubPairing;
  Handler? hubHandler;

  if (p2pEnabled) {
    final paths = MeshPadPaths(dataDir);
    final deviceStore = DeviceIdentityStore(paths: paths);
    final identity = await deviceStore.loadOrCreateIdentity(
      defaultDisplayName: hubDisplayName,
    );
    late final HubPairingService hub;
    lanSync = HeadlessLanSyncService(
      repository: opened.repository,
      deviceStore: deviceStore,
      engine: SyncEngine(notes: opened.repository, identity: identity),
      identity: identity,
      syncInterval: Duration(minutes: syncIntervalMinutes),
      changeHub: httpServer.changeHub,
      networkProfile: LanNetworkProfile.normal,
      onSyncStarted: () => hub.recordSyncStarted(),
      onSyncCompleted: (result) => unawaited(hub.recordSyncResult(result)),
      onPairingConfirmed: (peerId) => unawaited(hub.recordPairing(peerId: peerId)),
    );

    if (hubMode) {
      hubPairing = HubPairingService(
        lanSync: lanSync,
        deviceStore: deviceStore,
        repository: opened.repository,
        identity: identity,
      );
      hub = hubPairing!;
      await lanSync.start();
      await hubPairing!.start();
      hubHandler = HubWeb(pairing: hubPairing!)
          .buildRouter(webPort: port)
          .call;
    } else {
      hub = HubPairingService(
        lanSync: lanSync,
        deviceStore: deviceStore,
        repository: opened.repository,
        identity: identity,
      );
      await lanSync.start();
    }

    stdout.writeln(
      'LAN P2P sync enabled (interval: $syncIntervalMinutes min)',
    );
  }

  final server = await serveMeshPadHttp(
    server: httpServer,
    host: host,
    port: port,
    apiKeyAuth: auth,
    hubHandler: hubHandler,
  );

  stdout.writeln(
    'MeshPad ${hubMode ? 'hub' : 'server'} listening on http://${server.address.host}:${server.port}',
  );
  stdout.writeln('Data directory: $dataDir');
  if (hubMode) {
    stdout.writeln('Pairing page: http://<lan-ip>:$port/');
    if (lanSync != null) {
      final lanHost = lanSync.transport.localLanHost;
      final syncPort = lanSync.transport.localHttpPort;
      if (lanHost != null && syncPort != null) {
        stdout.writeln('LAN sync endpoint: $lanHost:$syncPort');
      }
    }
  }
  if (auth.isEnabled) {
    stdout.writeln('API key auth: enabled');
  }

  Future<void> shutdown() async {
    stdout.writeln('Shutting down…');
    await hubPairing?.dispose();
    await lanSync?.dispose();
    await opened.db.close();
    await server.close(force: true);
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => unawaited(shutdown()));
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) => unawaited(shutdown()));
  }
  await Completer<void>().future;
}
