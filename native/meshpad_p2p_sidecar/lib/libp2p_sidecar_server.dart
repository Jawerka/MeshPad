import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Localhost libp2p sidecar (PLAN §12 B.2). Rust backend replaces push/pull later.
class Libp2pSidecarServer {
  Libp2pSidecarServer();

  final _events = StreamController<Libp2pNativeEvent>.broadcast();
  String? _peerId;
  var _running = false;
  MdnsLanDiscovery? _discovery;

  Router buildRouter() {
    final router = Router();

    router.get('/health', (Request request) {
      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'backend': 'dart-mdns',
          'running': _running,
          'discovery': _discovery != null,
        }),
        headers: _jsonHeaders,
      );
    });

    router.post('/v1/start', (Request request) async {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      _peerId = payload['peer_id'] as String?;
      _running = true;
      await _startDiscovery();
      return Response.ok(
        jsonEncode({'status': 'started'}),
        headers: _jsonHeaders,
      );
    });

    router.post('/v1/stop', (Request request) async {
      _running = false;
      await _stopDiscovery();
      return Response.ok(
        jsonEncode({'status': 'stopped'}),
        headers: _jsonHeaders,
      );
    });

    router.post('/v1/sync', (Request request) async {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final peerId = payload['peer_id'] as String? ?? _peerId ?? 'sidecar';
      _events.add(
        Libp2pNativeSyncCompleted(peerId: peerId, noteCount: 0),
      );
      return Response.ok(
        jsonEncode({'status': 'delegated', 'backend': 'dart-mdns'}),
        headers: _jsonHeaders,
      );
    });

    router.get('/v1/events', (Request request) {
      Stream<List<int>> body() async* {
        yield utf8.encode(': connected\n\n');
        await for (final event in _events.stream) {
          yield utf8.encode(
            'data: ${jsonEncode(libp2pSidecarEventToJson(event))}\n\n',
          );
        }
      }

      return Response(
        200,
        headers: {
          'content-type': 'text/event-stream; charset=utf-8',
          'cache-control': 'no-cache',
          'connection': 'keep-alive',
        },
        body: body(),
      );
    });

    return router;
  }

  Future<void> _startDiscovery() async {
    if (_discovery != null) return;

    final localPeerId = _peerId;
    final discovery = MdnsLanDiscovery();
    discovery.onPeerDiscovered = (announcement) {
      if (localPeerId != null && announcement.peerId == localPeerId) return;
      _events.add(
        Libp2pNativePeerDiscovered(
          peerId: announcement.peerId,
          displayName: announcement.displayName,
          lanHost: announcement.host,
          httpPort: announcement.httpPort,
          tlsPort: announcement.tlsPort,
        ),
      );
    };

    await discovery.start(
      advertise: false,
      buildAnnouncement: () => LanPeerAnnouncement(
        peerId: localPeerId ?? 'sidecar',
        displayName: 'MeshPad',
        host: '127.0.0.1',
        httpPort: 0,
      ),
    );
    _discovery = discovery;
  }

  Future<void> _stopDiscovery() async {
    await _discovery?.stop();
    _discovery = null;
  }

  void emitPeerDiscovered({
    required String peerId,
    required String displayName,
    String? lanHost,
    int? httpPort,
    int? tlsPort,
  }) {
    _events.add(
      Libp2pNativePeerDiscovered(
        peerId: peerId,
        displayName: displayName,
        lanHost: lanHost,
        httpPort: httpPort,
        tlsPort: tlsPort,
      ),
    );
  }

  Future<void> close() async {
    await _stopDiscovery();
    await _events.close();
  }

  static const _jsonHeaders = {
    'content-type': 'application/json; charset=utf-8',
  };
}

Future<HttpServer> serveLibp2pSidecar({
  required Libp2pSidecarServer server,
  String host = '127.0.0.1',
  int port = 45839,
}) {
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(server.buildRouter().call);
  return shelf_io.serve(handler, host, port);
}
