import 'package:meshpad_server/api_key_auth.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('apiKeyAuthMiddleware rejects missing key', () async {
    final handler = apiKeyAuthMiddleware(ApiKeyAuth(apiKey: 'secret'))(
      (request) => Response.ok('ok'),
    );

    final response = await handler(
      Request('GET', Uri.parse('http://localhost/api/notes')),
    );
    expect(response.statusCode, 401);
    expect(await response.readAsString(), contains('unauthorized'));
  });

  test('apiKeyAuthMiddleware allows health without key', () async {
    final handler = apiKeyAuthMiddleware(ApiKeyAuth(apiKey: 'secret'))(
      (request) => Response.ok('ok'),
    );

    final response = await handler(
      Request('GET', Uri.parse('http://localhost/api/health')),
    );
    expect(response.statusCode, 200);
  });

  test('apiKeyAuthMiddleware allows request with valid key', () async {
    final handler = apiKeyAuthMiddleware(ApiKeyAuth(apiKey: 'secret'))(
      (request) => Response.ok('ok'),
    );

    final response = await handler(
      Request(
        'GET',
        Uri.parse('http://localhost/api/notes'),
        headers: {'X-MeshPad-Api-Key': 'secret'},
      ),
    );
    expect(response.statusCode, 200);
  });

  test('disabled auth passes through', () async {
    final handler = apiKeyAuthMiddleware(ApiKeyAuth())(
      (request) => Response.ok('ok'),
    );

    final response = await handler(
      Request('GET', Uri.parse('http://localhost/api/notes')),
    );
    expect(response.statusCode, 200);
  });
}
