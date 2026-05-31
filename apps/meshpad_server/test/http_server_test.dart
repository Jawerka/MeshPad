import 'dart:io';

import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_server/meshpad_server.dart';
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

  MeshPadHttpServer server() => MeshPadHttpServer(
        repository: repo,
        defaultAuthor: 'test',
      );

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
        Uri.parse('http://localhost/api/notes/$id/attachments/photo.bin'),
        body: payload,
        headers: {'Content-Type': 'application/octet-stream'},
      ),
    );
    expect(upload.statusCode, 200);

    final note = await repo.getNote(id);
    expect(note?.attachments.length, 1);
    expect(note?.attachments.first.name, 'photo.bin');
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
}
