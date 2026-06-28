import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_server/api_key_auth.dart';
import 'package:meshpad_server/api_rate_limit.dart';
import 'package:meshpad_server/meshpad_server.dart';
import 'package:meshpad_server/note_change_hub.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late NoteRepository repo;
  late MeshPadDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_http_');
    final opened = await openRepository(dataDir: tempDir.path);
    repo = opened.repository;
    db = opened.db;
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  MeshPadHttpServer server({ApiKeyAuth? apiKeyAuth}) => MeshPadHttpServer(
        repository: repo,
        defaultAuthor: 'test',
        apiKeyAuth: apiKeyAuth,
      );

  Handler protectedRouter({ApiKeyAuth? apiKeyAuth}) {
    final auth = apiKeyAuth ?? ApiKeyAuth();
    return Pipeline()
        .addMiddleware(apiKeyAuthMiddleware(auth))
        .addHandler(server(apiKeyAuth: auth).buildRouter().call);
  }

  test('GET /api/health', () async {
    final response = await server().buildRouter().call(
          Request('GET', Uri.parse('http://localhost/api/health')),
        );
    expect(response.statusCode, 200);
  });

  test('POST, PUT, DELETE and restore note', () async {
    final router = server().buildRouter();

    final create = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes'),
        body: '{"markdown":"hello api"}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(create.statusCode, 201);
    final id = RegExp(r'"id":"([^"]+)"').firstMatch(await create.readAsString())!.group(1)!;

    final update = await router.call(
      Request(
        'PUT',
        Uri.parse('http://localhost/api/notes/$id'),
        body: '{"markdown":"updated"}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(update.statusCode, 200);

    final delete = await router.call(
      Request('DELETE', Uri.parse('http://localhost/api/notes/$id')),
    );
    expect(delete.statusCode, 200);

    final trash = await router.call(
      Request('GET', Uri.parse('http://localhost/api/trash')),
    );
    expect(trash.statusCode, 200);

    final restore = await router.call(
      Request('POST', Uri.parse('http://localhost/api/notes/$id/restore')),
    );
    expect(restore.statusCode, 200);
  });

  test('PUT attachment uploads file to note', () async {
    final router = server().buildRouter();

    final create = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes'),
        body: '{"markdown":"with attachment"}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(create.statusCode, 201);
    final id = RegExp(r'"id":"([^"]+)"').firstMatch(await create.readAsString())!.group(1)!;

    final payload = [1, 2, 3, 4, 5];
    final upload = await router.call(
      Request(
        'PUT',
        Uri.parse('http://localhost/api/notes/$id/attachments/photo.png'),
        body: payload,
        headers: {'Content-Type': 'application/octet-stream'},
      ),
    );
    expect(upload.statusCode, 200);

    final note = await repo.getNote(id);
    expect(note?.attachments.length, 1);
    expect(note?.attachments.first.name, 'photo.png');
    expect(
      await repo.attachmentMatches(id, note!.attachments.first),
      isTrue,
    );
  });

  test('GET /api/notes supports pagination and count', () async {
    final router = server().buildRouter();

    for (var i = 0; i < 5; i++) {
      final create = await router.call(
        Request(
          'POST',
          Uri.parse('http://localhost/api/notes'),
          body: '{"markdown":"note $i"}',
          headers: {'Content-Type': 'application/json'},
        ),
      );
      expect(create.statusCode, 201);
    }

    final count = await router.call(
      Request('GET', Uri.parse('http://localhost/api/notes/count')),
    );
    expect(count.statusCode, 200);
    expect(await count.readAsString(), contains('"count":5'));

    final page = await router.call(
      Request(
        'GET',
        Uri.parse('http://localhost/api/notes?offset=2&limit=2'),
      ),
    );
    expect(page.statusCode, 200);
    final decoded = (await page.readAsString());
    expect(decoded.startsWith('['), isTrue);
    expect(decoded.split('"id"').length - 1, 2);
  });

  test('OPTIONS returns CORS headers', () async {
    final response = await corsHeaders()(
      (request) => Response.ok(''),
    ).call(Request('OPTIONS', Uri.parse('http://localhost/api/notes')));

    expect(response.statusCode, 200);
    expect(response.headers['access-control-allow-origin'], '*');
  });

  test('POST emits note_created on change hub', () async {
    final hub = NoteChangeHub();
    final router = MeshPadHttpServer(
      repository: repo,
      defaultAuthor: 'test',
      changeHub: hub,
    ).buildRouter();

    final events = <NoteChangeEvent>[];
    final sub = hub.stream.listen(events.add);

    final create = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes'),
        body: '{"markdown":"push me"}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(create.statusCode, 201);
    await Future<void>.delayed(Duration.zero);

    expect(events.any((e) => e.type == 'note_created'), isTrue);
    await sub.cancel();
    hub.dispose();
  });

  test('GET /api/notes?since= filters by updated_at', () async {
    final router = server().buildRouter();

    final create = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes'),
        body: '{"markdown":"old"}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(create.statusCode, 201);
    final id = RegExp(r'"id":"([^"]+)"')
        .firstMatch(await create.readAsString())!
        .group(1)!;

    final beforeUpdate = DateTime.now().toUtc();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final update = await router.call(
      Request(
        'PUT',
        Uri.parse('http://localhost/api/notes/$id'),
        body: '{"markdown":"new"}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(update.statusCode, 200);

    final since = beforeUpdate.toIso8601String();
    final filtered = await router.call(
      Request(
        'GET',
        Uri.parse('http://localhost/api/notes?since=$since'),
      ),
    );
    expect(filtered.statusCode, 200);
    final body = await filtered.readAsString();
    expect(body, contains(id));

    final none = await router.call(
      Request(
        'GET',
        Uri.parse(
          'http://localhost/api/notes?since=${DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String()}',
        ),
      ),
    );
    expect(none.statusCode, 200);
    expect(await none.readAsString(), '[]');
  });

  test('GET /api/events replays after Last-Event-ID', () async {
    final hub = NoteChangeHub();
    final router = MeshPadHttpServer(
      repository: repo,
      defaultAuthor: 'test',
      changeHub: hub,
    ).buildRouter();

    hub.noteCreated('first');
    hub.noteCreated('second');

    final response = await router.call(
      Request(
        'GET',
        Uri.parse('http://localhost/api/events'),
        headers: {'Last-Event-ID': '1'},
      ),
    );
    expect(response.statusCode, 200);

    final buffer = StringBuffer();
    await for (final chunk in response.read()) {
      buffer.write(utf8.decode(chunk));
      if (buffer.toString().contains('id: 2')) break;
    }
    final body = buffer.toString();
    expect(body, contains('id: 2'));
    expect(body, contains('note_created'));
    hub.dispose();
  });

  test('tags in CRUD and filter by ?tag=', () async {
    final router = server().buildRouter();

    final create = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes'),
        body: '{"markdown":"tagged","tags":["Work","work"]}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(create.statusCode, 201);
    final body = await create.readAsString();
    expect(body, contains('"tags":["work"]'));

    final id = RegExp(r'"id":"([^"]+)"').firstMatch(body)!.group(1)!;

    final tagsList = await router.call(
      Request('GET', Uri.parse('http://localhost/api/tags')),
    );
    expect(tagsList.statusCode, 200);
    expect(await tagsList.readAsString(), contains('work'));

    final filtered = await router.call(
      Request('GET', Uri.parse('http://localhost/api/notes?tag=work')),
    );
    expect(filtered.statusCode, 200);
    expect(await filtered.readAsString(), contains(id));

    final count = await router.call(
      Request('GET', Uri.parse('http://localhost/api/notes/count?tag=work')),
    );
    expect(count.statusCode, 200);
    expect(await count.readAsString(), contains('"count":1'));

    final update = await router.call(
      Request(
        'PUT',
        Uri.parse('http://localhost/api/notes/$id'),
        body: '{"tags":["ideas"]}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(update.statusCode, 200);
    expect(await update.readAsString(), contains('"ideas"'));
  });

  test('GET /api/events returns SSE content type', () async {
    final hub = NoteChangeHub();
    final router = MeshPadHttpServer(
      repository: repo,
      defaultAuthor: 'test',
      changeHub: hub,
    ).buildRouter();

    final response = await router.call(
      Request('GET', Uri.parse('http://localhost/api/events')),
    );
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], contains('text/event-stream'));

    final firstChunk = await response.read().first;
    expect(utf8.decode(firstChunk), contains(': connected'));
    hub.dispose();
  });

  test('GET attachment thumb returns JPEG preview', () async {
    final router = server().buildRouter();

    final create = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes'),
        body: '{"markdown":"image note"}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    expect(create.statusCode, 201);
    final id = RegExp(r'"id":"([^"]+)"')
        .firstMatch(await create.readAsString())!
        .group(1)!;

    final png = encodePng(Image(width: 640, height: 480));
    final upload = await router.call(
      Request(
        'PUT',
        Uri.parse('http://localhost/api/notes/$id/attachments/photo.png'),
        body: png,
        headers: {'Content-Type': 'application/octet-stream'},
      ),
    );
    expect(upload.statusCode, 200);

    final thumb = await router.call(
      Request(
        'GET',
        Uri.parse('http://localhost/api/notes/$id/attachments/photo.png/thumb'),
      ),
    );
    expect(thumb.statusCode, 200);
    expect(thumb.headers['content-type'], contains('image/jpeg'));

    final bytes = Uint8List.fromList(
      await thumb.read().expand((chunk) => chunk).toList(),
    );
    final decoded = decodeImage(bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(240));
  });

  test('API key required when configured', () async {
    final router = protectedRouter(apiKeyAuth: ApiKeyAuth(apiKey: 'secret'));

    final denied = await router.call(
      Request('GET', Uri.parse('http://localhost/api/notes/count')),
    );
    expect(denied.statusCode, 401);

    final allowed = await router.call(
      Request(
        'GET',
        Uri.parse('http://localhost/api/notes/count'),
        headers: {'X-MeshPad-Api-Key': 'secret'},
      ),
    );
    expect(allowed.statusCode, 200);
  });

  test('rejects disallowed attachment upload', () async {
    final router = server().buildRouter();
    final created = await router.call(
      Request(
        'POST',
        Uri.parse('http://localhost/api/notes'),
        body: '{"markdown":"x"}',
        headers: {'Content-Type': 'application/json'},
      ),
    );
    final id =
        (jsonDecode(await created.readAsString()) as Map)['id'] as String;

    final upload = await router.call(
      Request(
        'PUT',
        Uri.parse('http://localhost/api/notes/$id/attachments/evil.exe'),
        body: [1, 2, 3],
        headers: {'Content-Type': 'application/octet-stream'},
      ),
    );
    expect(upload.statusCode, 400);
    final body = jsonDecode(await upload.readAsString()) as Map;
    expect(body['error'], 'disallowed_type');
  });

  test('rate limit returns 429', () async {
    final limiter = ApiRateLimiter(maxPerMinute: 2);
    final handler = Pipeline()
        .addMiddleware(apiRateLimitMiddleware(limiter: limiter))
        .addHandler(server().buildRouter().call);

    expect(
      (await handler.call(
        Request('GET', Uri.parse('http://localhost/api/notes/count')),
      )).statusCode,
      200,
    );
    expect(
      (await handler.call(
        Request('GET', Uri.parse('http://localhost/api/notes/count')),
      )).statusCode,
      200,
    );
    expect(
      (await handler.call(
        Request('GET', Uri.parse('http://localhost/api/notes/count')),
      )).statusCode,
      429,
    );
    expect(
      (await handler.call(
        Request('GET', Uri.parse('http://localhost/api/health')),
      )).statusCode,
      200,
    );
  });
}
