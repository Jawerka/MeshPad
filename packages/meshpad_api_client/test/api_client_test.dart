import 'package:meshpad_api_client/meshpad_api_client.dart';
import 'package:test/test.dart';

void main() {
  test('noteFromApiJson maps server payload', () {
    final note = noteFromApiJson({
      'id': 'abc',
      'title': 't',
      'markdown': 'hello',
      'author': 'web',
      'created_at': '2026-05-29T12:00:00.000Z',
      'updated_at': '2026-05-29T12:01:00.000Z',
      'deleted': false,
      'deleted_at': null,
      'attachments': [
        {'name': 'a.png', 'size': 10, 'mime': 'image/png', 'sha256': 'x'},
      ],
    });

    expect(note.id, 'abc');
    expect(note.markdown, 'hello');
    expect(note.attachments.single.name, 'a.png');
  });

  test('MeshPadApiClient normalizes base URL', () {
    final client = MeshPadApiClient(baseUrl: '127.0.0.1:8787');
    expect(client.baseUri.toString(), 'http://127.0.0.1:8787/');
    client.close();
  });
}
