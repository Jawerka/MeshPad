import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'note_change_hub.dart';
import 'api_key_auth.dart';

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
    router.get('/api/notes/<noteId>/attachments/<fileName>/thumb', _getAttachmentThumb);
    router.get('/api/notes/<noteId>/attachments/<fileName>', _getAttachment);
    router.put('/api/notes/<noteId>/attachments/<fileName>', _putAttachment);
    router.get('/api/trash', _listTrash);
    router.get('/api/search', _searchNotes);
    router.get('/api/events', _streamEvents);

    return router;
  }

  Response _streamEvents(Request request) {
    Stream<List<int>> body() async* {
      yield utf8.encode(': connected\n\n');
      await for (final event in changeHub.stream) {
        yield utf8.encode('data: ${jsonEncode(event.toJson())}\n\n');
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

  Future<Response> _listNotes(Request request) async {
    final sort = _parseNoteSort(request.url.queryParameters['sort']);
    final params = request.url.queryParameters;
    final offset = int.tryParse(params['offset'] ?? '') ?? 0;
    final limitRaw = int.tryParse(params['limit'] ?? '') ?? 0;

    if (limitRaw > 0 || offset > 0) {
      final limit = limitRaw > 0 ? limitRaw.clamp(1, 200) : 40;
      final notes = await repository.listNotesSlice(
        offset: offset,
        limit: limit,
        sort: sort,
      );
      final body = notes.map(_noteJson).toList();
      return Response.ok(jsonEncode(body), headers: _jsonHeaders);
    }

    final notes = await repository.listNotes(sort: sort);
    final body = notes.map(_noteJson).toList();
    return Response.ok(jsonEncode(body), headers: _jsonHeaders);
  }

  Future<Response> _countNotes(Request request) async {
    final count = await repository.countActiveNotes();
    return Response.ok(jsonEncode({'count': count}), headers: _jsonHeaders);
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

      final note = await repository.createNote(
        title: payload['title'] as String? ?? '',
        markdown: markdown,
        author: payload['author'] as String? ?? defaultAuthor,
      );

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
      final note = await repository.updateNote(
        id,
        title: payload['title'] as String?,
        markdown: payload['markdown'] as String?,
      );
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

  Map<String, dynamic> _noteSummaryJson(Note note) => {
        'id': note.id,
        'title': note.title,
        'author': note.author,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt.toIso8601String(),
        'deleted': note.deleted,
        'deleted_at': note.deletedAt?.toIso8601String(),
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
}

Middleware corsHeaders() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization, X-MeshPad-Api-Key',
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
}) {
  var pipeline = Pipeline().addMiddleware(corsHeaders());
  if (apiKeyAuth != null && apiKeyAuth.isEnabled) {
    pipeline = pipeline.addMiddleware(apiKeyAuthMiddleware(apiKeyAuth));
  }
  final handler = pipeline
      .addMiddleware(logRequests())
      .addHandler(server.buildRouter().call);
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
