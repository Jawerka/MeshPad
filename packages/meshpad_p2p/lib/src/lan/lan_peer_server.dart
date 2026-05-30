import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';

import '../pairing_protocol.dart';
import 'lan_sync_codec.dart';

/// Local HTTP server exposing sync + pairing endpoints for LAN peers.
class LanPeerServer {
  LanPeerServer({
    required Future<SyncEngine> Function() getEngine,
    this.validatePairingPin,
  }) : _getEngine = getEngine;

  final Future<SyncEngine> Function() _getEngine;
  final bool Function(String pin)? validatePairingPin;

  PinPairingOffer? _pairingOffer;
  HttpServer? _server;

  int? get port => _server?.port;

  Future<int> start({InternetAddress? address}) async {
    if (_server != null) return _server!.port;

    _server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv4,
      0,
      shared: true,
    );
    _server!.listen(_handleRequest);
    return _server!.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void setPairingOffer(PinPairingOffer? offer) => _pairingOffer = offer;

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final response = await _route(request);
      request.response.statusCode = response.statusCode;
      if (response.headers != null) {
        response.headers!.forEach(request.response.headers.set);
      }
      if (response.body != null) {
        request.response.write(response.body);
      } else if (response.bodyBytes != null) {
        request.response.add(response.bodyBytes!);
      }
    } catch (_) {
      request.response.statusCode = 500;
      request.response.write('internal error');
    } finally {
      await request.response.close();
    }
  }

  Future<_HttpResponse> _route(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    if (path == '/meshpad/p2p/health' && method == 'GET') {
      return _HttpResponse.json({'status': 'ok'});
    }

    if (path == '/meshpad/p2p/catalog' && method == 'GET') {
      final engine = await _getEngine();
      final catalog = await engine.localCatalog();
      return _HttpResponse.json([
        for (final head in catalog) head.toJson(),
      ]);
    }

    if (path.startsWith('/meshpad/p2p/notes/') && method == 'GET') {
      final suffix = path.substring('/meshpad/p2p/notes/'.length);
      if (suffix.contains('/attachments/')) {
        return _getAttachment(suffix);
      }
      final id = suffix;
      final engine = await _getEngine();
      final snapshot = await engine.exportNote(id);
      if (snapshot == null) {
        return _HttpResponse(statusCode: 404, body: 'note not found');
      }
      return _HttpResponse.json(remoteSnapshotToJson(snapshot));
    }

    if (path.startsWith('/meshpad/p2p/notes/') && method == 'PUT') {
      final id = path.substring('/meshpad/p2p/notes/'.length);
      if (id.contains('/attachments/')) {
        return _putAttachment(request, id);
      }
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final snapshot = remoteSnapshotFromJson(json);
      if (snapshot.meta.id != id) {
        return _HttpResponse(statusCode: 400, body: 'id mismatch');
      }
      final engine = await _getEngine();
      final result = await engine.applyRemote(snapshot);
      return _HttpResponse.json({'result': noteApplyResultWire(result)});
    }

    if (path == '/meshpad/p2p/pairing/offer' && method == 'GET') {
      final offer = _pairingOffer;
      if (offer == null || offer.isExpired) {
        return _HttpResponse(statusCode: 404, body: 'no active offer');
      }
      return _HttpResponse.json(offer.toJson());
    }

    if (path == '/meshpad/p2p/pairing/confirm' && method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      final confirm = PinPairingConfirm.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
      final offer = _pairingOffer;
      if (offer == null ||
          offer.isExpired ||
          offer.pin != confirm.pin ||
          offer.peerId != confirm.peerId) {
        return _HttpResponse(statusCode: 403, body: 'invalid pin');
      }
      if (validatePairingPin != null && !validatePairingPin!(confirm.pin)) {
        return _HttpResponse(statusCode: 403, body: 'invalid pin');
      }
      _pairingOffer = null;
      return _HttpResponse.json({'status': 'trusted'});
    }

    return _HttpResponse(statusCode: 404, body: 'not found');
  }

  Future<_HttpResponse> _getAttachment(String suffix) async {
    final parts = suffix.split('/attachments/');
    if (parts.length != 2) {
      return _HttpResponse(statusCode: 400, body: 'invalid attachment path');
    }

    final noteId = parts[0];
    final fileName = Uri.decodeComponent(parts[1]);
    final engine = await _getEngine();
    final note = await engine.notes.getNote(noteId);
    if (note == null) {
      return _HttpResponse(statusCode: 404, body: 'note not found');
    }

    AttachmentMeta? meta;
    for (final item in note.attachments) {
      if (item.name == fileName) {
        meta = item;
        break;
      }
    }
    if (meta == null) {
      return _HttpResponse(statusCode: 404, body: 'attachment not found');
    }

    final bytes = await engine.notes.readAttachmentBytes(noteId, fileName);
    if (bytes == null) {
      return _HttpResponse(statusCode: 404, body: 'attachment file missing');
    }

    return _HttpResponse(
      bodyBytes: bytes,
      headers: {
        'content-type': meta.mime ?? 'application/octet-stream',
        'content-length': '${bytes.length}',
      },
    );
  }

  Future<_HttpResponse> _putAttachment(HttpRequest request, String suffix) async {
    final parts = suffix.split('/attachments/');
    if (parts.length != 2) {
      return _HttpResponse(statusCode: 400, body: 'invalid attachment path');
    }

    final noteId = parts[0];
    final fileName = Uri.decodeComponent(parts[1]);
    final engine = await _getEngine();
    final note = await engine.notes.getNote(noteId);
    if (note == null) {
      return _HttpResponse(statusCode: 404, body: 'note not found');
    }

    AttachmentMeta? meta;
    for (final item in note.toMeta().attachments) {
      if (item.name == fileName) {
        meta = item;
        break;
      }
    }

    final bodyBytes = await request.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );

    if (meta == null) {
      return _HttpResponse(statusCode: 404, body: 'attachment not in note meta');
    }

    await engine.notes.storeRemoteAttachment(noteId, meta, bodyBytes);
    return _HttpResponse.json({'status': 'stored'});
  }
}

class _HttpResponse {
  const _HttpResponse({
    this.statusCode = 200,
    this.body,
    this.bodyBytes,
    this.headers,
  });

  factory _HttpResponse.json(Object payload) {
    return _HttpResponse(
      body: jsonEncode(payload),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  final int statusCode;
  final String? body;
  final List<int>? bodyBytes;
  final Map<String, String>? headers;
}
