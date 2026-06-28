import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';

import '../pairing_protocol.dart';
import 'lan_sync_auth.dart';
import 'lan_catalog_body.dart';
import 'lan_sync_codec.dart';
import 'lan_tls_identity.dart';
import '../meshpad_log.dart';

/// Default LAN HTTP port (stable across restarts when free).
const meshpadPreferredLanHttpPort = 45838;

typedef PairingConfirmedHandler = Future<void> Function(PinPairingConfirm confirm);
typedef CascadeSyncHandler = Future<void> Function(String? excludePeerId);
typedef TrustedPeerLookup = Future<TrustedDeviceRecord?> Function(String peerId);

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

    if (!isLanSyncPublicPath(path)) {
      final lookup = lookupTrustedPeer;
      if (lookup != null) {
        final failure = await validateLanSyncAuth(
          callerPeerId: request.headers.value(meshpadSyncPeerIdHeader),
          authToken: request.headers.value(meshpadSyncAuthTokenHeader),
          method: method,
          path: path,
          timestampHeader:
              request.headers.value(meshpadSyncTimestampHeader),
          signatureHeader:
              request.headers.value(meshpadSyncSignatureHeader),
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
      return _HttpResponse.json({
        'status': 'ok',
        if (tlsIdentity != null) ...{
          'tls': true,
          'tls_cert_sha256': tlsIdentity!.certSha256Hex,
          if (tlsPort != null) 'tls_port': tlsPort,
        },
      });
    }

    if (path == '/meshpad/p2p/catalog' && method == 'GET') {
      final engine = await _getEngine();
      final localPeerId = engine.identity.peerId;
      final catalog = await engine.localCatalog();
      final acceptGzip = !requestWantsPayloadEncryption(
            request.headers.value(meshpadPayloadEncHeader),
          ) &&
          lanCatalogAcceptsGzip(
            request.headers.value(HttpHeaders.acceptEncodingHeader),
          );
      final encoded = encodeLanCatalogBody(
        catalog,
        useGzip: acceptGzip,
      );
      final jsonText = utf8.decode(
        encoded.gzipped ? gzip.decode(encoded.bytes) : encoded.bytes,
      );
      return _encryptedOrPlainJson(
        request: request,
        jsonText: jsonText,
        localPeerId: localPeerId,
        plainBytes: encoded.bytes,
        plainHeaders: encoded.gzipped
            ? {
                'content-type': 'application/json; charset=utf-8',
                'content-encoding': lanCatalogGzipEncoding,
              }
            : {'content-type': 'application/json; charset=utf-8'},
      );
    }

    if (path.startsWith('/meshpad/p2p/notes/') && method == 'GET') {
      final suffix = path.substring('/meshpad/p2p/notes/'.length);
      if (suffix.contains('/attachments/')) {
        return _getAttachment(suffix);
      }
      final id = suffix;
      final engine = await _getEngine();
      final localPeerId = engine.identity.peerId;
      final snapshot = await engine.exportNote(id);
      if (snapshot == null) {
        return _HttpResponse(statusCode: 404, body: 'note not found');
      }
      return _encryptedOrPlainJson(
        request: request,
        jsonText: jsonEncode(remoteSnapshotToJson(snapshot)),
        localPeerId: localPeerId,
      );
    }

    if (path.startsWith('/meshpad/p2p/notes/') && method == 'PUT') {
      final id = path.substring('/meshpad/p2p/notes/'.length);
      if (id.contains('/attachments/')) {
        return _putAttachment(request, id);
      }
      final body = await utf8.decoder.bind(request).join();
      final engine = await _getEngine();
      final localPeerId = engine.identity.peerId;
      final clearBody = await _decryptRequestBody(request, body, localPeerId);
      final json = jsonDecode(clearBody) as Map<String, dynamic>;
      final snapshot = remoteSnapshotFromJson(json);
      if (snapshot.meta.id != id) {
        return _HttpResponse(statusCode: 400, body: 'id mismatch');
      }
      final result = await engine.applyRemote(snapshot);
      return _encryptedOrPlainJson(
        request: request,
        jsonText: jsonEncode({'result': noteApplyResultWire(result)}),
        localPeerId: engine.identity.peerId,
      );
    }

    if (path == '/meshpad/p2p/pairing/offer' && method == 'GET') {
      final offer = _pairingOffer;
      if (offer == null || offer.isExpired) {
        if (offer != null && offer.isExpired) {
          _pairingOffer = null;
        }
        return _HttpResponse(statusCode: 404, body: 'no active offer');
      }
      return _HttpResponse.json(offer.toJson());
    }

    if (path == '/meshpad/p2p/sync/cascade' && method == 'POST') {
      String? excludePeerId;
      try {
        final body = await utf8.decoder.bind(request).join();
        if (body.trim().isNotEmpty) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          excludePeerId = json['excludePeerId'] as String?;
        }
      } catch (_) {
        excludePeerId = null;
      }
      final handler = onCascadeSyncRequested;
      if (handler != null) {
        unawaited(handler(excludePeerId));
      }
      return _HttpResponse.json({'status': 'accepted'});
    }

    if (path == '/meshpad/p2p/pairing/confirm' && method == 'POST') {
      final clientKey = pairingClientKeyFromAddress(
        request.connectionInfo?.remoteAddress,
      );
      if (_pairingRateLimiter.isBlocked(clientKey)) {
        MeshPadLog.warn('pairing', 'confirm rate limited for $clientKey');
        return _HttpResponse(statusCode: 429, body: 'rate limited');
      }

      final body = await utf8.decoder.bind(request).join();
      final confirm = PinPairingConfirm.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
      final offer = _pairingOffer;
      if (offer == null ||
          offer.isExpired ||
          offer.pin != confirm.pin ||
          offer.peerId != confirm.peerId) {
        _pairingRateLimiter.recordFailure(clientKey);
        return _HttpResponse(statusCode: 403, body: 'invalid pin');
      }
      if (validatePairingPin != null && !validatePairingPin!(confirm.pin)) {
        _pairingRateLimiter.recordFailure(clientKey);
        return _HttpResponse(statusCode: 403, body: 'invalid pin');
      }
      _pairingOffer = null;
      _pairingRateLimiter.recordSuccess(clientKey);
      MeshPadLog.pairing(
        'PIN confirmed for ${confirm.peerId} by '
        '${confirm.initiatorPeerId ?? 'unknown initiator'}',
      );
      if (onPairingConfirmed != null) {
        await onPairingConfirmed!(confirm);
      }
      return _HttpResponse.json({'status': 'trusted'});
    }

    return _HttpResponse(statusCode: 404, body: 'not found');
  }

  Future<_HttpResponse> _getAttachment(String suffix) async {
    const uploadSuffix = '/upload';
    if (suffix.endsWith(uploadSuffix)) {
      return _getAttachmentUploadStatus(
        suffix.substring(0, suffix.length - uploadSuffix.length),
      );
    }

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

  Future<_HttpResponse> _getAttachmentUploadStatus(String suffix) async {
    final parts = suffix.split('/attachments/');
    if (parts.length != 2) {
      return _HttpResponse(statusCode: 400, body: 'invalid attachment path');
    }

    final noteId = parts[0];
    final fileName = Uri.decodeComponent(parts[1]);
    final engine = await _getEngine();
    final status = await engine.notes.attachmentUploadStatus(noteId, fileName);
    if (status == null) {
      return _HttpResponse(statusCode: 404, body: 'attachment not found');
    }

    return _HttpResponse.json(status.toJson());
  }

  Future<_HttpResponse> _putAttachment(HttpRequest request, String suffix) async {
    if (request.headers.value(meshpadUploadOffsetHeader) != null) {
      return _putAttachmentChunk(request, suffix);
    }

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
    final parts = suffix.split('/attachments/');
    if (parts.length != 2) {
      return _HttpResponse(statusCode: 400, body: 'invalid attachment path');
    }

    final noteId = parts[0];
    final fileName = Uri.decodeComponent(parts[1]);
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
