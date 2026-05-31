import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:meshpad_core/meshpad_core.dart';

import '../pairing_protocol.dart';
import 'lan_sync_auth.dart';
import 'lan_sync_codec.dart';
import 'lan_sync_transfer_progress.dart';
import 'lan_tls_identity.dart';

/// HTTP client for [LanPeerServer] sync endpoints.
class HttpRemoteSyncGateway implements RemoteSyncGateway {
  HttpRemoteSyncGateway({
    required LanPeerEndpoint endpoint,
    this.callerPeerId,
    this.authToken,
    this.tlsCertSha256,
  }) : _endpoint = endpoint;

  final LanPeerEndpoint _endpoint;
  final String? callerPeerId;
  final String? authToken;
  final String? tlsCertSha256;

  bool get _useTlsForSync =>
      tlsCertSha256 != null && _endpoint.tlsPort != null;

  @override
  Future<List<NoteHead>> fetchCatalog() async {
    final body = await _get('/meshpad/p2p/catalog');
    final decoded = jsonDecode(body) as List<dynamic>;
    return noteHeadsFromJsonList(decoded);
  }

  @override
  Future<RemoteNoteSnapshot?> fetchNote(String id) async {
    try {
      final body = await _get('/meshpad/p2p/notes/$id');
      return remoteSnapshotFromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } on HttpRemoteSyncException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<NoteApplyResult> pushNote(RemoteNoteSnapshot snapshot) async {
    final body = await _putJson(
      '/meshpad/p2p/notes/${snapshot.meta.id}',
      remoteSnapshotToJson(snapshot),
    );
    final json = jsonDecode(body) as Map<String, dynamic>;
    return noteApplyResultFromWire(json['result'] as String? ?? 'unchanged');
  }

  @override
  Future<List<int>?> fetchAttachment(String noteId, String fileName) async {
    final encodedName = Uri.encodeComponent(fileName);
    try {
      return await _getBytes('/meshpad/p2p/notes/$noteId/attachments/$encodedName');
    } on HttpRemoteSyncException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<void> pushAttachment(
    String noteId,
    AttachmentMeta meta,
    List<int> bytes,
  ) async {
    final encodedName = Uri.encodeComponent(meta.name);
    final path = '/meshpad/p2p/notes/$noteId/attachments/$encodedName';
    if (bytes.length <= attachmentUploadChunkThreshold) {
      await _putBytes(path, bytes);
      return;
    }
    await _putAttachmentResumable(
      path: path,
      fileName: meta.name,
      meta: meta,
      bytes: bytes,
    );
  }

  Future<void> _putAttachmentResumable({
    required String path,
    required String fileName,
    required AttachmentMeta meta,
    required List<int> bytes,
  }) async {
    final total = bytes.length;
    final expectedSha256 = meta.sha256 ?? sha256OfBytes(bytes);
    var offset = await _fetchUploadOffset(path);

    while (offset < total) {
      final end = min(offset + attachmentUploadChunkSize, total);
      final chunk = bytes.sublist(offset, end);
      offset = await _putUploadChunk(
        path: path,
        fileName: fileName,
        offset: offset,
        total: total,
        sha256: expectedSha256,
        chunk: chunk,
      );
    }
  }

  Future<int> _fetchUploadOffset(String attachmentPath) async {
    try {
      final body = await _get('$attachmentPath/upload');
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['received'] as int? ?? 0;
    } on HttpRemoteSyncException catch (e) {
      if (e.statusCode == 404) return 0;
      rethrow;
    }
  }

  Future<int> _putUploadChunk({
    required String path,
    required String fileName,
    required int offset,
    required int total,
    required String sha256,
    required List<int> chunk,
  }) async {
    final client = _syncClient();
    try {
      final request = await client.putUrl(_uri(path, secure: _useTlsForSync));
      _applySyncAuthHeaders(request);
      request.headers.set(meshpadUploadOffsetHeader, '$offset');
      request.headers.set(meshpadUploadTotalHeader, '$total');
      request.headers.set(meshpadUploadSha256Header, sha256);
      request.headers.contentType = ContentType('application', 'octet-stream');
      request.contentLength = chunk.length;
      request.add(chunk);
      lanSyncTransferProgress.report(
        fileName: fileName,
        transferred: offset + chunk.length,
        total: total,
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode == 409) {
        final refreshed = await _fetchUploadOffset(path);
        if (refreshed == offset) {
          throw HttpRemoteSyncException(response.statusCode, body);
        }
        return refreshed;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpRemoteSyncException(response.statusCode, body);
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['received'] as int? ?? offset + chunk.length;
    } finally {
      client.close(force: true);
    }
  }

  Future<PinPairingOffer?> fetchPairingOffer() async {
    try {
      final body = await _get('/meshpad/p2p/pairing/offer', secure: false);
      return PinPairingOffer.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } on HttpRemoteSyncException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<bool> confirmPairing(PinPairingConfirm confirm) async {
    try {
      final body = await _post(
        '/meshpad/p2p/pairing/confirm',
        confirm.toJson(),
        secure: false,
      );
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['status'] == 'trusted';
    } on HttpRemoteSyncException {
      return false;
    }
  }

  Future<bool> checkHealth({bool secure = false}) async {
    try {
      await _get('/meshpad/p2p/health', secure: secure);
      return true;
    } on Object {
      return false;
    }
  }

  Future<String?> fetchTlsCertSha256() async {
    if (_endpoint.tlsPort == null) {
      final body = await _get('/meshpad/p2p/health', secure: false);
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['tls_cert_sha256'] as String?;
    }
    final client = LanTlsIdentity.createPinnedHttpClient(allowUnpinned: true);
    try {
      final request = await client.getUrl(
        _uri('/meshpad/p2p/health', secure: true),
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['tls_cert_sha256'] as String?;
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<LanPeerEndpoint> enrichEndpointFromHealth(
    LanPeerEndpoint endpoint,
  ) async {
    final body = await _get('/meshpad/p2p/health', secure: false);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final tlsPort = json['tls_port'] as int?;
    return LanPeerEndpoint(
      peerId: endpoint.peerId,
      displayName: endpoint.displayName,
      host: endpoint.host,
      httpPort: endpoint.httpPort,
      tlsPort: tlsPort ?? endpoint.tlsPort,
    );
  }

  Future<void> requestCascadeSync({String? excludePeerId}) async {
    await _post(
      '/meshpad/p2p/sync/cascade',
      {
        if (excludePeerId != null) 'excludePeerId': excludePeerId,
      },
    );
  }

  Uri _uri(String path, {required bool secure}) =>
      _endpoint.uriFor(path, secure: secure);

  HttpClient _syncClient() => LanTlsIdentity.createPinnedHttpClient(
        expectedSha256Hex: tlsCertSha256,
        allowUnpinned: tlsCertSha256 == null,
      );

  HttpClient _plainClient() => HttpClient();

  Future<String> _get(String path, {bool? secure}) async {
    final useTls = secure ?? _useTlsForSync;
    final client = useTls ? _syncClient() : _plainClient();
    try {
      final request = await client.getUrl(_uri(path, secure: useTls));
      _applySyncAuthHeaders(request);
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpRemoteSyncException(response.statusCode, body);
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _putJson(String path, Map<String, dynamic> payload) async {
    final client = _syncClient();
    try {
      final request = await client.putUrl(_uri(path, secure: _useTlsForSync));
      _applySyncAuthHeaders(request);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpRemoteSyncException(response.statusCode, body);
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _putBytes(String path, List<int> bytes) async {
    final client = _syncClient();
    try {
      final request = await client.putUrl(_uri(path, secure: _useTlsForSync));
      _applySyncAuthHeaders(request);
      request.headers.contentType = ContentType('application', 'octet-stream');
      request.contentLength = bytes.length;
      final fileName = path.split('/').last;
      const chunkSize = 64 * 1024;
      var sent = 0;
      while (sent < bytes.length) {
        final end =
            (sent + chunkSize > bytes.length) ? bytes.length : sent + chunkSize;
        request.add(bytes.sublist(sent, end));
        sent = end;
        lanSyncTransferProgress.report(
          fileName: fileName,
          transferred: sent,
          total: bytes.length,
        );
      }
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decoder.bind(response).join();
        throw HttpRemoteSyncException(response.statusCode, body);
      }
      await response.drain();
    } finally {
      client.close(force: true);
    }
  }

  Future<List<int>> _getBytes(String path) async {
    final client = _syncClient();
    try {
      final request = await client.getUrl(_uri(path, secure: _useTlsForSync));
      _applySyncAuthHeaders(request);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decoder.bind(response).join();
        throw HttpRemoteSyncException(response.statusCode, body);
      }
      final total = response.contentLength;
      final fileName = path.split('/').last;
      final buffer = <int>[];
      await for (final chunk in response) {
        buffer.addAll(chunk);
        if (total > 0) {
          lanSyncTransferProgress.report(
            fileName: fileName,
            transferred: buffer.length,
            total: total,
          );
        }
      }
      return buffer;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _post(
    String path,
    Map<String, dynamic> payload, {
    bool? secure,
  }) async {
    final useTls = secure ?? _useTlsForSync;
    final client = useTls ? _syncClient() : _plainClient();
    try {
      final request = await client.postUrl(_uri(path, secure: useTls));
      if (!isLanSyncPublicPath(path)) {
        _applySyncAuthHeaders(request);
      }
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpRemoteSyncException(response.statusCode, body);
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }

  void _applySyncAuthHeaders(HttpClientRequest request) {
    final peerId = callerPeerId;
    if (peerId != null) {
      request.headers.set(meshpadSyncPeerIdHeader, peerId);
    }
    final token = authToken;
    if (token != null) {
      request.headers.set(meshpadSyncAuthTokenHeader, token);
    }
  }
}

class HttpRemoteSyncException implements Exception {
  HttpRemoteSyncException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'HttpRemoteSyncException($statusCode): $body';
}
