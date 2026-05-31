import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';

import '../pairing_protocol.dart';
import 'lan_sync_codec.dart';
import 'lan_sync_transfer_progress.dart';

/// HTTP client for [LanPeerServer] sync endpoints.
class HttpRemoteSyncGateway implements RemoteSyncGateway {
  HttpRemoteSyncGateway({required LanPeerEndpoint endpoint})
      : _endpoint = endpoint;

  final LanPeerEndpoint _endpoint;

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
    await _putBytes(
      '/meshpad/p2p/notes/$noteId/attachments/$encodedName',
      bytes,
    );
  }

  Future<PinPairingOffer?> fetchPairingOffer() async {
    try {
      final body = await _get('/meshpad/p2p/pairing/offer');
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
      );
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['status'] == 'trusted';
    } on HttpRemoteSyncException {
      return false;
    }
  }

  Future<bool> checkHealth() async {
    try {
      await _get('/meshpad/p2p/health');
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> requestCascadeSync({String? excludePeerId}) async {
    await _post(
      '/meshpad/p2p/sync/cascade',
      {
        if (excludePeerId != null) 'excludePeerId': excludePeerId,
      },
    );
  }

  Future<String> _get(String path) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(_endpoint.uriFor(path));
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
    final client = HttpClient();
    try {
      final request = await client.putUrl(_endpoint.uriFor(path));
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
    final client = HttpClient();
    try {
      final request = await client.putUrl(_endpoint.uriFor(path));
      request.headers.contentType = ContentType('application', 'octet-stream');
      request.contentLength = bytes.length;
      final fileName = path.split('/').last;
      const chunkSize = 64 * 1024;
      var sent = 0;
      while (sent < bytes.length) {
        final end = (sent + chunkSize > bytes.length) ? bytes.length : sent + chunkSize;
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
    final client = HttpClient();
    try {
      final request = await client.getUrl(_endpoint.uriFor(path));
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

  Future<String> _post(String path, Map<String, dynamic> payload) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(_endpoint.uriFor(path));
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
}

class HttpRemoteSyncException implements Exception {
  HttpRemoteSyncException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'HttpRemoteSyncException($statusCode): $body';
}
