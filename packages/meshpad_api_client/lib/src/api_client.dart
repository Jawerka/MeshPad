import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meshpad_core/meshpad_core.dart';

import 'api_exception.dart';
import 'note_json.dart';

/// REST client for [apps/meshpad_server] (Web / thin clients).
class MeshPadApiClient {
  MeshPadApiClient({
    required String baseUrl,
    http.Client? httpClient,
  })  : _base = _normalizeBase(baseUrl),
        _http = httpClient ?? http.Client();

  final Uri _base;
  final http.Client _http;

  Uri get baseUri => _base;

  Future<void> checkHealth() async {
    final response = await _get('/api/health');
    if (response.statusCode != 200) {
      throw MeshPadApiException.fromResponse(response.statusCode, response.body);
    }
  }

  Future<List<Note>> listNotes() async {
    final response = await _get('/api/notes');
    _ensureOk(response);
    return notesFromApiList(response.body);
  }

  Future<List<Note>> listTrash() async {
    final response = await _get('/api/trash');
    _ensureOk(response);
    return notesFromApiList(response.body);
  }

  Future<List<NoteSearchHit>> searchNotes(String query) async {
    final response = await _get(
      '/api/search',
      query: {'q': query},
    );
    _ensureOk(response);
    return searchHitsFromApiList(response.body);
  }

  Future<Note> getNote(String id) async {
    final response = await _get('/api/notes/$id');
    _ensureOk(response);
    return noteFromApiBody(response.body);
  }

  Future<Note> createNote({
    String title = '',
    required String markdown,
    String? author,
  }) async {
    final response = await _post(
      '/api/notes',
      body: {
        'title': title,
        'markdown': markdown,
        if (author != null) 'author': author,
      },
    );
    if (response.statusCode != 201) {
      throw MeshPadApiException.fromResponse(response.statusCode, response.body);
    }
    return noteFromApiBody(response.body);
  }

  Future<Note> updateNote(
    String id, {
    String? title,
    String? markdown,
  }) async {
    final response = await _put(
      '/api/notes/$id',
      body: {
        if (title != null) 'title': title,
        if (markdown != null) 'markdown': markdown,
      },
    );
    _ensureOk(response);
    return noteFromApiBody(response.body);
  }

  Future<void> deleteNote(String id) async {
    final response = await _delete('/api/notes/$id');
    _ensureOk(response);
  }

  Future<Note> restoreNote(String id) async {
    final response = await _post('/api/notes/$id/restore');
    _ensureOk(response);
    return noteFromApiBody(response.body);
  }

  Uri attachmentUri(String noteId, String fileName) {
    return _uri(
      '/api/notes/$noteId/attachments/${Uri.encodeComponent(fileName)}',
    );
  }

  void close() => _http.close();

  Future<http.Response> _get(
    String path, {
    Map<String, String>? query,
  }) {
    return _http.get(_uri(path, query: query));
  }

  Future<http.Response> _post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _http.post(
      _uri(path),
      headers: _jsonHeaders,
      body: body == null ? null : jsonEncode(body),
    );
  }

  Future<http.Response> _put(
    String path, {
    required Map<String, dynamic> body,
  }) {
    return _http.put(
      _uri(path),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> _delete(String path) {
    return _http.delete(_uri(path));
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final resolved = _base.resolve(path.startsWith('/') ? path.substring(1) : path);
    if (query == null || query.isEmpty) return resolved;
    return resolved.replace(queryParameters: query);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MeshPadApiException.fromResponse(response.statusCode, response.body);
    }
  }

  static Uri _normalizeBase(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw const MeshPadApiException('api_config', 'URL сервера не задан');
    }
    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.parse(withScheme);
    if (uri.host.isEmpty) {
      throw MeshPadApiException('api_config', 'Некорректный URL: $baseUrl');
    }
    return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
  }

  static const _jsonHeaders = {'Content-Type': 'application/json; charset=utf-8'};
}
