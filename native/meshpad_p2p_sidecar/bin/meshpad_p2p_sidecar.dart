import 'dart:io';

import 'package:meshpad_p2p_sidecar/libp2p_sidecar_server.dart';

Future<void> main(List<String> args) async {
  var host = InternetAddress.loopbackIPv4.address;
  var port = 45839;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--host':
        if (i + 1 < args.length) host = args[++i];
      case '--port':
        if (i + 1 < args.length) port = int.parse(args[++i]);
      case '--help':
      case '-h':
        stdout.writeln('''
MeshPad libp2p sidecar (stub, Phase B.2)

Usage:
  dart run meshpad_p2p_sidecar [--host HOST] [--port PORT]

Default: http://127.0.0.1:45839
''');
        return;
    }
  }

  final sidecar = Libp2pSidecarServer();
  final server =
      await serveLibp2pSidecar(server: sidecar, host: host, port: port);
  stdout.writeln(
      'libp2p sidecar listening on http://${server.address.host}:${server.port}');
}
