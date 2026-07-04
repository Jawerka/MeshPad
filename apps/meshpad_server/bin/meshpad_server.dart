import 'dart:async';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_server/headless_lan_sync.dart';
import 'package:meshpad_server/api_key_auth.dart';
import 'package:meshpad_server/meshpad_server.dart';

Future<void> main(List<String> args) async {
  var dataDir = './var/meshpad';
  var host = InternetAddress.loopbackIPv4.address;
  var port = 8787;
  var p2pEnabled = false;
  var syncIntervalMinutes = 15;
  String? apiKey;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--data-dir':
        if (i + 1 < args.length) dataDir = args[++i];
      case '--host':
        if (i + 1 < args.length) host = args[++i];
      case '--port':
        if (i + 1 < args.length) port = int.parse(args[++i]);
      case '--p2p':
        p2pEnabled = true;
      case '--sync-interval':
        if (i + 1 < args.length) {
          syncIntervalMinutes = int.parse(args[++i]);
        }
      case '--api-key':
        if (i + 1 < args.length) apiKey = args[++i];
      case '--help':
      case '-h':
        stdout.writeln('''
MeshPad headless HTTP server

Usage:
  dart run meshpad_server [--data-dir PATH] [--host HOST] [--port PORT]
                          [--p2p] [--sync-interval MINUTES] [--api-key KEY]

Options:
  --p2p              Enable LAN P2P sync (UDP discovery + HTTP) with trusted peers
  --sync-interval    Auto-sync interval in minutes when --p2p is set (default: 15)
  --api-key          Require API key on /api/* (except /api/health). Env: MESHPAD_API_KEY

Endpoints:
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

  apiKey ??= Platform.environment['MESHPAD_API_KEY'];

  final opened = await openRepository(dataDir: dataDir);
  final auth = ApiKeyAuth(apiKey: apiKey);
  final httpServer = MeshPadHttpServer(
    repository: opened.repository,
    defaultAuthor: 'MeshPad Server',
    apiKeyAuth: auth,
  );

  final server = await serveMeshPadHttp(
    server: httpServer,
    host: host,
    port: port,
    apiKeyAuth: auth,
  );

  HeadlessLanSyncService? lanSync;
  if (p2pEnabled) {
    final paths = MeshPadPaths(dataDir);
    final deviceStore = DeviceIdentityStore(paths: paths);
    final identity = await deviceStore.loadOrCreateIdentity(
      defaultDisplayName: 'MeshPad Server',
    );
    lanSync = HeadlessLanSyncService(
      repository: opened.repository,
      deviceStore: deviceStore,
      engine: SyncEngine(notes: opened.repository, identity: identity),
      identity: identity,
      syncInterval: Duration(minutes: syncIntervalMinutes),
      changeHub: httpServer.changeHub,
    );
    await lanSync.start();
    stdout.writeln(
      'LAN P2P sync enabled (interval: $syncIntervalMinutes min)',
    );
  }

  stdout.writeln(
      'MeshPad server listening on http://${server.address.host}:${server.port}');
  stdout.writeln('Data directory: $dataDir');
  if (auth.isEnabled) {
    stdout.writeln('API key auth: enabled');
  }

  if (p2pEnabled) {
    ProcessSignal.sigint.watch().listen((_) async {
      stdout.writeln('Shutting down…');
      await lanSync?.dispose();
      await opened.db.close();
      await server.close(force: true);
      exit(0);
    });
    await Completer<void>().future;
  }
}
