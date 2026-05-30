import 'dart:convert';
import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Headless HTTP API for Web client / LAN (Sprint 5, ARCHITECTURE.md).
class MeshPadHttpServer {
  MeshPadHttpServer({
    required this.repository,
    required this.defaultAuthor,
  });

  final NoteRepository repository;
  final String defaultAuthor;

  Router buildRouter() {
    final router = Router();

    router.get('/api/health', (Request request) {
      return Response.ok(
        jsonEncode({'status': 'ok', 'service': 'meshpad_server'}),
        headers: _jsonHeaders,
      );
    });

    router.get('/api/notes', _listNotes);
    router.get('/api/notes/<id>', _getNote);
    router.post('/api/notes', _createNote);
    router.put('/api/notes/<id>', _updateNote);
    router.delete('/api/notes/<id>', _deleteNote);
    router.post('/api/notes/<id>/restore', _restoreNote);
    router.get('/api/notes/<noteId>/attachments/<fileName>', _getAttachment);
    router.get('/api/trash', _listTrash);
    router.get('/api/search', _searchNotes);

    return router;
  }

  Future<Response> _listNotes(Request request) async {
    final notes = await repository.listNotes(sort: NoteSort.createdAt);
    final body = notes.map(_noteJson).toList();
    return Response.ok(jsonEncode(body), headers: _jsonHeaders);
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
    return Response.ok(jsonEncode(_noteJson(note)), headers: _jsonHeaders);
  }

  Future<Response> _getAttachment(
    Request request,
    String noteId,
    String fileName,
  ) async {
    final note = await repository.getNote(noteId);
    if (note == null || note.deleted) {
      return Response.notFound('note not found');
    }

    AttachmentMeta? attachment;
    for (final item in note.attachments) {
      if (item.name == fileName) {
        attachment = item;
        break;
      }
    }
    if (attachment == null) {
      return Response.notFound('attachment not found');
    }

    final path = repository.attachmentPath(noteId, fileName);
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

  Map<String, dynamic> _noteJson(Note note) => {
        'id': note.id,
        'title': note.title,
        'markdown': note.markdown,
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
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
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
}) {
  final handler = const Pipeline()
      .addMiddleware(corsHeaders())
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
