import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Localhost libp2p sidecar (PLAN §12 B.2). Rust backend replaces push/pull later.
class Libp2pSidecarServer {
  Libp2pSidecarServer({this.enableDiscovery = true});

  /// When false, skips mDNS browse (faster/deterministic in unit tests).
  final bool enableDiscovery;

  final _events = StreamController<Libp2pNativeEvent>.broadcast(sync: true);
  final _wireStore = Libp2pSidecarWireStore();
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
          'wire_notes': _wireStore.noteCount,
          'wire_attachments': _wireStore.attachmentCount,
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

    router.get('/v1/wire/catalog', (Request request) {
      return Response.ok(
        jsonEncode(_wireStore.catalogHeadsJson()),
        headers: _jsonHeaders,
      );
    });

    router.get('/v1/wire/batch/export', (Request request) {
      return Response.ok(
        jsonEncode(_wireStore.exportBatch().toJson()),
        headers: _jsonHeaders,
      );
    });

    router.post('/v1/wire/batch/import', (Request request) async {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final imported = _wireStore.importBatch(WireSyncBatch.fromJson(payload));
      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'backend': 'dart-mdns',
          'lan_fallback': false,
          'imported': imported,
        }),
        headers: _jsonHeaders,
      );
    });

    router.post('/v1/wire/push', (Request request) async {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final snapshot = payload['snapshot'];
      if (snapshot is Map<String, dynamic>) {
        _wireStore.upsertSnapshot(snapshot);
      }
      return Response.ok(
        jsonEncode({
          'status': 'accepted',
          'backend': 'dart-mdns',
          'lan_fallback': false,
          if (payload['peer_id'] != null) 'peer_id': payload['peer_id'],
        }),
        headers: _jsonHeaders,
      );
    });

    router.post('/v1/wire/attachment/push', (Request request) async {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final noteId = payload['note_id'] as String? ?? '';
      final name = payload['name'] as String? ?? '';
      final encoded = payload['bytes_base64'] as String? ?? '';
      List<int> bytes = const [];
      if (encoded.isNotEmpty) {
        bytes = base64Decode(encoded);
      }
      final accepted = _wireStore.upsertAttachment(
        noteId: noteId,
        name: name,
        bytes: bytes,
      );
      return Response.ok(
        jsonEncode({
          'status': accepted ? 'accepted' : 'ignored',
          'backend': 'dart-mdns',
          'lan_fallback': false,
          if (payload['peer_id'] != null) 'peer_id': payload['peer_id'],
        }),
        headers: _jsonHeaders,
      );
    });

    router.post('/v1/wire/attachment/pull', (Request request) async {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final noteId = payload['note_id'] as String? ?? '';
      final name = payload['name'] as String? ?? '';
      final bytes = _wireStore.pullAttachment(noteId: noteId, name: name);
      if (bytes == null) {
        return Response(
          404,
          body: jsonEncode({
            'status': 'not_found',
            'backend': 'dart-mdns',
            'lan_fallback': false,
          }),
          headers: _jsonHeaders,
        );
      }
      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'backend': 'dart-mdns',
          'lan_fallback': false,
          'note_id': noteId,
          'name': name,
          'bytes_base64': base64Encode(bytes),
        }),
        headers: _jsonHeaders,
      );
    });

    router.post('/v1/wire/pull', (Request request) async {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final noteIds = (payload['note_ids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      final notes = _wireStore.pullSnapshots(noteIds);
      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'backend': 'dart-mdns',
          'lan_fallback': false,
          if (payload['peer_id'] != null) 'peer_id': payload['peer_id'],
          'note_ids': noteIds,
          'notes': notes,
        }),
        headers: _jsonHeaders,
      );
    });

    router.post('/v1/sync', (Request request) async {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final peerId = payload['peer_id'] as String? ?? _peerId ?? 'sidecar';
      final remoteBase = payload['remote_wire_base'] as String?;
      var imported = 0;
      var pushed = 0;
      if (remoteBase != null && remoteBase.trim().isNotEmpty) {
        final remote = Libp2pSidecarWireClient(baseUrl: remoteBase.trim());
        imported = await _wireStore.importFromRemote(remote);
        pushed = await _wireStore.pushToRemote(remote);
      }
      _events.add(
        Libp2pNativeSyncCompleted(
          peerId: peerId,
          noteCount: _wireStore.noteCount,
        ),
      );
      return Response.ok(
        jsonEncode({
          'status': 'delegated',
          'backend': 'dart-mdns',
          'lan_fallback': false,
          'wire_imported': imported,
          'wire_pushed': pushed,
          'peer_id': peerId,
        }),
        headers: _jsonHeaders,
      );
    });

    router.get('/v1/events', (Request request) {
      Stream<List<int>> eventBytes() async* {
        yield utf8.encode(': connected\n\n');
        yield* _events.stream.map(
          (event) => utf8.encode(
            'data: ${jsonEncode(libp2pSidecarEventToJson(event))}\n\n',
          ),
        );
      }

      return Response(
        200,
        headers: {
          'content-type': 'text/event-stream; charset=utf-8',
          'cache-control': 'no-cache',
          'connection': 'keep-alive',
        },
        body: eventBytes(),
      );
    });

    return router;
  }

  Future<void> _startDiscovery() async {
    if (!enableDiscovery || _discovery != null) return;

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
    _wireStore.clear();
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
