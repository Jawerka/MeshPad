import 'dart:io';

import 'package:meshpad_server/meshpad_server.dart';

Future<void> main(List<String> args) async {
  var dataDir = './var/meshpad';
  var host = InternetAddress.loopbackIPv4.address;
  var port = 8787;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--data-dir':
        if (i + 1 < args.length) dataDir = args[++i];
      case '--host':
        if (i + 1 < args.length) host = args[++i];
      case '--port':
        if (i + 1 < args.length) port = int.parse(args[++i]);
      case '--help':
      case '-h':
        stdout.writeln('''
MeshPad headless HTTP server

Usage:
  dart run meshpad_server [--data-dir PATH] [--host HOST] [--port PORT]

Endpoints:
  GET  /api/health
  GET  /api/notes
  GET  /api/notes/<id>
  POST /api/notes  {"markdown":"...", "title":"", "author":""}
''');
        return;
    }
  }

  final opened = await openRepository(dataDir: dataDir);
  final httpServer = MeshPadHttpServer(
    repository: opened.repository,
    defaultAuthor: 'MeshPad Server',
  );

  final server = await serveMeshPadHttp(
    server: httpServer,
    host: host,
    port: port,
  );

  stdout.writeln('MeshPad server listening on http://${server.address.host}:${server.port}');
  stdout.writeln('Data directory: $dataDir');
}
