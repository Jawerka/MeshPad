import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'note_change_hub.dart';
import 'api_key_auth.dart';
import 'api_rate_limit.dart';

/// Headless HTTP API for Web client / LAN (Sprint 5, ARCHITECTURE.md).
class MeshPadHttpServer {
  MeshPadHttpServer({
    required this.repository,
    required this.defaultAuthor,
    NoteChangeHub? changeHub,
    this.apiKeyAuth,
  }) : changeHub = changeHub ?? NoteChangeHub();

  final NoteRepository repository;
  final String defaultAuthor;
  final NoteChangeHub changeHub;
  final ApiKeyAuth? apiKeyAuth;

  Router buildRouter() {
    final router = Router();

    router.get('/api/health', (Request request) {
      return Response.ok(
        jsonEncode({
          'status': 'ok',
          'service': 'meshpad_server',
          'auth': apiKeyAuth?.isEnabled == true ? 'api_key' : 'none',
        }),
        headers: _jsonHeaders,
      );
    });

    router.get('/api/notes', _listNotes);
    router.get('/api/notes/count', _countNotes);
    router.get('/api/notes/<id>', _getNote);
    router.post('/api/notes', _createNote);
    router.put('/api/notes/<id>', _updateNote);
    router.delete('/api/notes/<id>', _deleteNote);
    router.post('/api/notes/<id>/restore', _restoreNote);
    router.get('/api/notes/<noteId>/attachments/<fileName>/thumb',
        _getAttachmentThumb);
    router.get('/api/notes/<noteId>/attachments/<fileName>', _getAttachment);
    router.put('/api/notes/<noteId>/attachments/<fileName>', _putAttachment);
    router.get('/api/tags', _listTags);
    router.get('/api/trash', _listTrash);
    router.get('/api/search', _searchNotes);
    router.get('/api/events', _streamEvents);

    return router;
  }

  Response _streamEvents(Request request) {
    final lastHeader =
        request.headers['last-event-id'] ?? request.headers['Last-Event-ID'];
    final lastEventId = int.tryParse(lastHeader?.trim() ?? '');

    Stream<List<int>> body() async* {
      yield utf8.encode(': connected\n\n');
      for (final event in changeHub.eventsAfter(lastEventId)) {
        yield _sseChunk(event);
      }
      var cursor = lastEventId ?? 0;
      await for (final event in changeHub.stream) {
        if (event.id <= cursor) continue;
        cursor = event.id;
        yield _sseChunk(event);
      }
    }

    return Response(
      200,
      headers: {
        'content-type': 'text/event-stream; charset=utf-8',
        'cache-control': 'no-cache',
        'connection': 'keep-alive',
        'x-accel-buffering': 'no',
      },
      body: body(),
    );
  }

  List<int> _sseChunk(NoteChangeEvent event) {
    return utf8.encode(
      'id: ${event.id}\ndata: ${jsonEncode(event.toJson())}\n\n',
    );
  }

  Future<Response> _listNotes(Request request) async {
    final sort = _parseNoteSort(request.url.queryParameters['sort']);
    final params = request.url.queryParameters;
    final tag = _tagFromQuery(params);
    final sinceRaw = params['since']?.trim();
    if (sinceRaw != null && sinceRaw.isNotEmpty) {
      try {
        final since = DateTime.parse(sinceRaw).toUtc();
        final notes = await repository.listNotesUpdatedSince(
          since,
          sort: sort,
          tag: tag,
        );
        final body = notes.map(_noteJson).toList();
        return Response.ok(jsonEncode(body), headers: _jsonHeaders);
      } on FormatException {
        return Response(
          400,
          body: '{"error":"invalid since (ISO-8601 expected)"}',
          headers: _jsonHeaders,
        );
      }
    }

    final offset = int.tryParse(params['offset'] ?? '') ?? 0;
    final limitRaw = int.tryParse(params['limit'] ?? '') ?? 0;

    if (limitRaw > 0 || offset > 0) {
      final limit = limitRaw > 0 ? limitRaw.clamp(1, 200) : 40;
      final notes = await repository.listNotesSlice(
        offset: offset,
        limit: limit,
        sort: sort,
        tag: tag,
      );
      final body = notes.map(_noteJson).toList();
      return Response.ok(jsonEncode(body), headers: _jsonHeaders);
    }

    final notes = await repository.listNotes(sort: sort, tag: tag);
    final body = notes.map(_noteJson).toList();
    return Response.ok(jsonEncode(body), headers: _jsonHeaders);
  }

  Future<Response> _countNotes(Request request) async {
    final tag = _tagFromQuery(request.url.queryParameters);
    final count = await repository.countActiveNotes(tag: tag);
    return Response.ok(jsonEncode({'count': count}), headers: _jsonHeaders);
  }

  Future<Response> _listTags(Request request) async {
    final tags = await repository.listDistinctTags();
    return Response.ok(jsonEncode(tags), headers: _jsonHeaders);
  }

  NoteSort _parseNoteSort(String? raw) {
    return raw == 'updated_at' ? NoteSort.updatedAt : NoteSort.createdAt;
  }

  Future<Response> _listTrash(Request request) async {
    final notes = await repository.listTrash();
    final body = notes.map(_noteJson).toList();
    return Response.ok(jsonEncode(body), headers: _jsonHeaders);
  }

  Future<Response> _searchNotes(Request request) async {
    final query = request.url.queryParameters['q']?.trim() ?? '';
    if (query.isEmpty) {
      return Response.ok('[]', headers: _jsonHeaders);
    }

    final hits = await repository.searchNotes(query);
    final body = hits
        .map(
          (hit) => {
            'snippet': hit.snippet,
            'note': _noteJson(hit.note),
          },
        )
        .toList();
    return Response.ok(jsonEncode(body), headers: _jsonHeaders);
  }

  Future<Response> _getNote(Request request, String id) async {
    final note = await repository.getNote(id);
    if (note == null || note.deleted) {
      return Response.notFound(
        jsonEncode({'error': 'note_not_found'}),
        headers: _jsonHeaders,
      );
    }

    return Response.ok(
      jsonEncode(_noteJson(note)),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _createNote(Request request) async {
    try {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final markdown = payload['markdown'] as String? ?? '';
      if (markdown.trim().isEmpty) {
        return Response(
          400,
          body: jsonEncode({'error': 'markdown_required'}),
          headers: _jsonHeaders,
        );
      }

      var note = await repository.createNote(
        title: payload['title'] as String? ?? '',
        markdown: markdown,
        author: payload['author'] as String? ?? defaultAuthor,
      );
      final tags = _tagsFromPayload(payload);
      if (tags != null) {
        note = await repository.setNoteTags(note.id, tags);
      }

      changeHub.noteCreated(note.id);

      return Response(
        201,
        body: jsonEncode(_noteJson(note)),
        headers: _jsonHeaders,
      );
    } on FormatException {
      return Response(
        400,
        body: jsonEncode({'error': 'invalid_json'}),
        headers: _jsonHeaders,
      );
    }
  }

  Future<Response> _updateNote(Request request, String id) async {
    try {
      final payload =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      var note = await repository.updateNote(
        id,
        title: payload['title'] as String?,
        markdown: payload['markdown'] as String?,
      );
      final tags = _tagsFromPayload(payload);
      if (tags != null) {
        note = await repository.setNoteTags(id, tags);
      }
      changeHub.noteUpdated(note.id);
      return Response.ok(jsonEncode(_noteJson(note)), headers: _jsonHeaders);
    } on StateError {
      return Response.notFound(
        jsonEncode({'error': 'note_not_found'}),
        headers: _jsonHeaders,
      );
    } on FormatException {
      return Response(
        400,
        body: jsonEncode({'error': 'invalid_json'}),
        headers: _jsonHeaders,
      );
    }
  }

  Future<Response> _deleteNote(Request request, String id) async {
    await repository.deleteNote(id);
    changeHub.noteDeleted(id);
    return Response.ok(
      jsonEncode({'status': 'deleted'}),
      headers: _jsonHeaders,
    );
  }

  Future<Response> _restoreNote(Request request, String id) async {
    await repository.restoreNote(id);
    final note = await repository.getNote(id);
    if (note == null) {
      return Response.notFound(
        jsonEncode({'error': 'note_not_found'}),
        headers: _jsonHeaders,
      );
    }
    changeHub.noteRestored(note.id);
    return Response.ok(jsonEncode(_noteJson(note)), headers: _jsonHeaders);
  }

  Future<Response> _getAttachmentThumb(
    Request request,
    String noteId,
    String fileName,
  ) async {
    final decodedName = Uri.decodeComponent(fileName);
    final note = await repository.getNote(noteId);
    if (note == null || note.deleted) {
      return Response.notFound('note not found');
    }

    var found = false;
    for (final item in note.attachments) {
      if (item.name == decodedName) {
        found = true;
        break;
      }
    }
    if (!found) {
      return Response.notFound('attachment not found');
    }

    final paths = repository.paths;
    final thumbFile = await resolveImageThumbnailFile(
      attachmentPath: repository.attachmentPath(noteId, decodedName),
      thumbsDir: paths.thumbsDir(noteId),
      attachmentName: decodedName,
    );
    if (thumbFile == null) {
      return Response.notFound('thumbnail unavailable');
    }

    final bytes = await thumbFile.readAsBytes();
    return Response.ok(
      bytes,
      headers: {
        'content-type': 'image/jpeg',
        'cache-control': 'public, max-age=3600',
      },
    );
  }

  Future<Response> _getAttachment(
    Request request,
    String noteId,
    String fileName,
  ) async {
    final decodedName = Uri.decodeComponent(fileName);
    final note = await repository.getNote(noteId);
    if (note == null || note.deleted) {
      return Response.notFound('note not found');
    }

    AttachmentMeta? attachment;
    for (final item in note.attachments) {
      if (item.name == decodedName) {
        attachment = item;
        break;
      }
    }
    if (attachment == null) {
      return Response.notFound('attachment not found');
    }

    final path = repository.attachmentPath(noteId, decodedName);
    final file = File(path);
    if (!await file.exists()) {
      return Response.notFound('file missing');
    }

    final bytes = await file.readAsBytes();
    return Response.ok(
      bytes,
      headers: {
        'content-type': attachment.mime ?? 'application/octet-stream',
        'cache-control': 'public, max-age=3600',
      },
    );
  }

  Future<Response> _putAttachment(
    Request request,
    String noteId,
    String fileName,
  ) async {
    final decodedName = Uri.decodeComponent(fileName);
    final bytes = await request.read().expand((chunk) => chunk).toList();
    if (bytes.isEmpty) {
      return Response(
        400,
        body: jsonEncode({'error': 'empty_body'}),
        headers: _jsonHeaders,
      );
    }

    try {
      final note = await repository.addAttachmentFromBytes(
        noteId,
        fileName: decodedName,
        bytes: bytes,
      );
      changeHub.attachmentAdded(note.id);
      return Response.ok(jsonEncode(_noteJson(note)), headers: _jsonHeaders);
    } on AttachmentUploadRejectedException catch (e) {
      return _attachmentRejectedResponse(e);
    } on NoteNotFoundException {
      return Response.notFound(
        jsonEncode({'error': 'note_not_found'}),
        headers: _jsonHeaders,
      );
    } on NoteDeletedException {
      return Response(
        400,
        body: jsonEncode({'error': 'note_deleted'}),
        headers: _jsonHeaders,
      );
    }
  }

  String? _tagFromQuery(Map<String, String> params) {
    final raw = params['tag']?.trim();
    if (raw == null || raw.isEmpty) return null;
    return normalizeTag(raw);
  }

  List<String>? _tagsFromPayload(Map<String, dynamic> payload) {
    if (!payload.containsKey('tags')) return null;
    final raw = payload['tags'];
    if (raw == null) return const [];
    if (raw is! List) {
      throw const FormatException('tags must be a JSON array');
    }
    return normalizeTags(raw.map((e) => '$e'));
  }

  Map<String, dynamic> _noteSummaryJson(Note note) => {
        'id': note.id,
        'title': note.title,
        'author': note.author,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt.toIso8601String(),
        'deleted': note.deleted,
        'deleted_at': note.deletedAt?.toIso8601String(),
        'tags': note.tags,
        'preview': _preview(note.markdown),
        'attachments': [
          for (final a in note.attachments)
            {
              'name': a.name,
              'size': a.size,
              'mime': a.mime,
              'sha256': a.sha256,
            },
        ],
      };

  Map<String, dynamic> _noteJson(Note note) => {
        ..._noteSummaryJson(note),
        'markdown': note.markdown,
      };

  static String _preview(String markdown) {
    final line = markdown.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    return line.length > 120 ? '${line.substring(0, 120)}…' : line;
  }

  static const _jsonHeaders = {
    'content-type': 'application/json; charset=utf-8',
  };

  static Response _attachmentRejectedResponse(
    AttachmentUploadRejectedException error,
  ) {
    final status = switch (error.code) {
      'too_large' => 413,
      _ => 400,
    };
    return Response(
      status,
      body: jsonEncode({'error': error.code, 'message': error.message}),
      headers: _jsonHeaders,
    );
  }
}

Middleware corsHeaders() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization, X-MeshPad-Api-Key, Last-Event-ID',
  };

  return (Handler inner) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: headers);
      }
      final response = await inner(request);
      return response.change(headers: headers);
    };
  };
}

Future<HttpServer> serveMeshPadHttp({
  required MeshPadHttpServer server,
  required String host,
  required int port,
  ApiKeyAuth? apiKeyAuth,
  Handler? hubHandler,
}) {
  Handler apiHandler() {
    var pipeline = Pipeline()
        .addMiddleware(corsHeaders())
        .addMiddleware(apiRateLimitMiddleware());
    if (apiKeyAuth != null && apiKeyAuth.isEnabled) {
      pipeline = pipeline.addMiddleware(apiKeyAuthMiddleware(apiKeyAuth));
    }
    return pipeline
        .addMiddleware(logRequests())
        .addHandler(server.buildRouter().call);
  }

  final handler = hubHandler == null
      ? apiHandler()
      : (Request request) {
          final path = request.url.path;
          if (path.isEmpty ||
              path == '/' ||
              path.startsWith('hub/') ||
              path.startsWith('hub')) {
            return hubHandler(request);
          }
          return apiHandler()(request);
        };

  return shelf_io.serve(handler, host, port);
}

Future<({NoteRepository repository, MeshPadDatabase db})> openRepository({
  required String dataDir,
  String defaultAuthor = 'MeshPad Server',
}) async {
  await Directory(dataDir).create(recursive: true);
  final db = createMeshPadDatabase(dataDir);
  final repo = createNoteRepository(
    dataDir: dataDir,
    defaultAuthor: defaultAuthor,
    database: db,
  );
  await repo.reconcileFromFilesystem();
  return (repository: repo, db: db);
}
