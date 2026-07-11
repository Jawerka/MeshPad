import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';

import '../pairing_protocol.dart';
import 'cascade_sync_request.dart';
import 'lan_attachment_path.dart';
import 'lan_sync_auth.dart';
import 'lan_catalog_body.dart';
import 'lan_sync_codec.dart';
import 'lan_tls_identity.dart';
import '../meshpad_log.dart';

part 'lan_peer_server_routes.dart';

/// Default LAN HTTP port (stable across restarts when free).
const meshpadPreferredLanHttpPort = 45838;

typedef PairingConfirmedHandler = Future<void> Function(
    PinPairingConfirm confirm);
typedef CascadeSyncHandler = Future<void> Function(CascadeSyncRequest request);
typedef TrustedPeerLookup = Future<TrustedDeviceRecord?> Function(
    String peerId);

/// Local HTTP server exposing sync + pairing endpoints for LAN peers.
class LanPeerServer {
  LanPeerServer({
    required Future<SyncEngine> Function() getEngine,
    this.validatePairingPin,
    this.onPairingConfirmed,
    this.onCascadeSyncRequested,
    this.lookupTrustedPeer,
    PairingConfirmRateLimiter? pairingRateLimiter,
    this.preferredPort = meshpadPreferredLanHttpPort,
    this.tlsIdentity,
    this.preferredTlsPort = meshpadPreferredLanTlsPort,
  })  : _getEngine = getEngine,
        _pairingRateLimiter = pairingRateLimiter ?? PairingConfirmRateLimiter();

  final Future<SyncEngine> Function() _getEngine;
  final bool Function(String pin)? validatePairingPin;
  final PairingConfirmedHandler? onPairingConfirmed;
  final CascadeSyncHandler? onCascadeSyncRequested;
  final TrustedPeerLookup? lookupTrustedPeer;
  final PairingConfirmRateLimiter _pairingRateLimiter;
  final int preferredPort;
  final LanTlsIdentity? tlsIdentity;
  final int preferredTlsPort;

  PinPairingOffer? _pairingOffer;
  HttpServer? _server;
  HttpServer? _tlsServer;

  int? get port => _server?.port;
  int? get tlsPort => _tlsServer?.port;

  Future<int> start({InternetAddress? address}) async {
    if (_server != null) return _server!.port;

    final bindAddress = address ?? InternetAddress.anyIPv4;
    try {
      _server = await HttpServer.bind(
        bindAddress,
        preferredPort,
        shared: true,
      );
      MeshPadLog.lan('HTTP server on preferred port $preferredPort');
    } on SocketException {
      _server = await HttpServer.bind(bindAddress, 0, shared: true);
      MeshPadLog.warn(
        'lan',
        'HTTP server on dynamic port ${_server!.port} '
            '(preferred $preferredPort busy — add firewall rule or free the port)',
      );
    }
    _server!.listen(_handleRequest);

    final identity = tlsIdentity;
    if (identity != null) {
      try {
        _tlsServer = await HttpServer.bindSecure(
          bindAddress,
          preferredTlsPort,
          identity.securityContext,
          shared: true,
        );
        MeshPadLog.lan('TLS server on preferred port $preferredTlsPort');
      } on SocketException {
        _tlsServer = await HttpServer.bindSecure(
          bindAddress,
          0,
          identity.securityContext,
          shared: true,
        );
        MeshPadLog.warn(
          'lan',
          'TLS server on dynamic port ${_tlsServer!.port} '
              '(preferred $preferredTlsPort busy)',
        );
      }
      _tlsServer!.listen(_handleRequest);
    }

    return _server!.port;
  }

  Future<void> stop() async {
    await _tlsServer?.close(force: true);
    _tlsServer = null;
    await _server?.close(force: true);
    _server = null;
  }

  void setPairingOffer(PinPairingOffer? offer) => _pairingOffer = offer;

  PinPairingOffer? get currentPairingOffer => _pairingOffer;

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
    } on FormatException catch (_) {
      request.response.statusCode = 400;
      request.response.write('bad request');
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

    if (!isLanSyncPublicPath(path)) {
      final lookup = lookupTrustedPeer;
      if (lookup != null) {
        final failure = await validateLanSyncAuth(
          callerPeerId: request.headers.value(meshpadSyncPeerIdHeader),
          authToken: request.headers.value(meshpadSyncAuthTokenHeader),
          method: method,
          path: path,
          timestampHeader: request.headers.value(meshpadSyncTimestampHeader),
          signatureHeader: request.headers.value(meshpadSyncSignatureHeader),
          lookupTrusted: lookup,
        );
        if (failure != null) {
          return _HttpResponse(
            statusCode: statusCodeFor(failure),
            body: bodyFor(failure),
          );
        }
      }
    }

    if (path == '/meshpad/p2p/health' && method == 'GET') {
      return _handleHealthRoute();
    }

    if (path == '/meshpad/p2p/catalog' && method == 'GET') {
      return _handleCatalogRoute(request);
    }

    if (path.startsWith('/meshpad/p2p/notes/') && method == 'GET') {
      final suffix = path.substring('/meshpad/p2p/notes/'.length);
      return _handleGetNoteRoute(request, suffix);
    }

    if (path.startsWith('/meshpad/p2p/notes/') && method == 'PUT') {
      final id = path.substring('/meshpad/p2p/notes/'.length);
      return _handlePutNoteRoute(request, id);
    }

    if (path == '/meshpad/p2p/pairing/offer' && method == 'GET') {
      return _handlePairingOfferRoute();
    }

    if (path == '/meshpad/p2p/sync/cascade' && method == 'POST') {
      return _handleCascadeRoute(request);
    }

    if (path == '/meshpad/p2p/pairing/confirm' && method == 'POST') {
      return _handlePairingConfirmRoute(request);
    }

    return _HttpResponse(statusCode: 404, body: 'not found');
  }

  Future<_HttpResponse> _getAttachment(String suffix) async {
    final withoutUpload = attachmentPathWithoutUploadSuffix(suffix);
    if (withoutUpload != suffix) {
      return _getAttachmentUploadStatus(withoutUpload);
    }

    final parsed = parseLanAttachmentPath(suffix);
    if (parsed == null) {
      return _HttpResponse(statusCode: 400, body: 'invalid attachment path');
    }

    final noteId = parsed.noteId;
    final fileName = parsed.fileName;
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

  Future<_HttpResponse> _getAttachmentUploadStatus(String suffix) async {
    final parsed = parseLanAttachmentPath(suffix);
    if (parsed == null) {
      return _HttpResponse(statusCode: 400, body: 'invalid attachment path');
    }

    final noteId = parsed.noteId;
    final fileName = parsed.fileName;
    final engine = await _getEngine();
    final status = await engine.notes.attachmentUploadStatus(noteId, fileName);
    if (status == null) {
      return _HttpResponse(statusCode: 404, body: 'attachment not found');
    }

    return _HttpResponse.json(status.toJson());
  }

  Future<_HttpResponse> _putAttachment(
      HttpRequest request, String suffix) async {
    if (request.headers.value(meshpadUploadOffsetHeader) != null) {
      return _putAttachmentChunk(request, suffix);
    }

    final parsed = parseLanAttachmentPath(suffix);
    if (parsed == null) {
      return _HttpResponse(statusCode: 400, body: 'invalid attachment path');
    }

    final noteId = parsed.noteId;
    final fileName = parsed.fileName;
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
      return _HttpResponse(
          statusCode: 404, body: 'attachment not in note meta');
    }

    try {
      validateAttachmentUpload(
        fileName: fileName,
        byteLength: bodyBytes.length,
      );
    } on AttachmentUploadRejectedException catch (e) {
      return _attachmentRejectedResponse(e);
    }

    await engine.notes.storeRemoteAttachment(noteId, meta, bodyBytes);
    return _HttpResponse.json({'status': 'stored'});
  }

  Future<_HttpResponse> _putAttachmentChunk(
    HttpRequest request,
    String suffix,
  ) async {
    final parsed = parseLanAttachmentPath(suffix);
    if (parsed == null) {
      return _HttpResponse(statusCode: 400, body: 'invalid attachment path');
    }

    final noteId = parsed.noteId;
    final fileName = parsed.fileName;
    final offset = int.tryParse(
      request.headers.value(meshpadUploadOffsetHeader) ?? '',
    );
    final total = int.tryParse(
      request.headers.value(meshpadUploadTotalHeader) ?? '',
    );
    final sha = request.headers.value(meshpadUploadSha256Header);
    if (offset == null || total == null || sha == null || sha.isEmpty) {
      return _HttpResponse(statusCode: 400, body: 'invalid upload headers');
    }

    try {
      validateAttachmentUpload(fileName: fileName, byteLength: total);
    } on AttachmentUploadRejectedException catch (e) {
      return _attachmentRejectedResponse(e);
    }

    final bodyBytes = await request.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );

    final engine = await _getEngine();
    try {
      final result = await engine.notes.receiveAttachmentUploadChunk(
        noteId: noteId,
        fileName: fileName,
        offset: offset,
        totalSize: total,
        sha256: sha,
        bytes: bodyBytes,
      );
      return _HttpResponse.json(result.toJson());
    } on AttachmentUploadOffsetException catch (e) {
      return _HttpResponse(
        statusCode: 409,
        body: 'offset mismatch; expected ${e.expectedOffset}',
      );
    } on StateError catch (e) {
      return _HttpResponse(statusCode: 400, body: e.message);
    }
  }

  Future<String?> _authTokenForCaller(String? callerPeerId) async {
    if (callerPeerId == null || lookupTrustedPeer == null) return null;
    final record = await lookupTrustedPeer!(callerPeerId);
    return record?.authToken;
  }

  Future<String> _decryptRequestBody(
    HttpRequest request,
    String body,
    String localPeerId,
  ) async {
    if (!bodyLooksEncrypted(body)) return body;
    final caller = request.headers.value(meshpadSyncPeerIdHeader);
    final token = await _authTokenForCaller(caller);
    if (token == null || caller == null) return body;
    return decryptJsonString(
      body: body,
      authToken: token,
      localPeerId: localPeerId,
      remotePeerId: caller,
    );
  }

  Future<_HttpResponse> _encryptedOrPlainJson({
    required HttpRequest request,
    required String jsonText,
    required String localPeerId,
    List<int>? plainBytes,
    Map<String, String>? plainHeaders,
  }) async {
    final caller = request.headers.value(meshpadSyncPeerIdHeader);
    final wantsEnc = requestWantsPayloadEncryption(
      request.headers.value(meshpadPayloadEncHeader),
    );
    final token = await _authTokenForCaller(caller);
    if (wantsEnc && token != null && caller != null) {
      final enc = await encryptJsonString(
        json: jsonText,
        authToken: token,
        localPeerId: localPeerId,
        remotePeerId: caller,
      );
      return _HttpResponse(
        body: enc,
        headers: {HttpHeaders.contentTypeHeader: encryptedPayloadContentType()},
      );
    }
    if (plainBytes != null) {
      return _HttpResponse(bodyBytes: plainBytes, headers: plainHeaders);
    }
    return _HttpResponse.json(jsonDecode(jsonText));
  }
}

_HttpResponse _attachmentRejectedResponse(AttachmentUploadRejectedException e) {
  final code = switch (e.code) {
    'too_large' => 413,
    _ => 400,
  };
  return _HttpResponse(statusCode: code, body: e.code);
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
