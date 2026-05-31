import 'package:meshpad_api_client/meshpad_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('meshPadApiKeyHeaders', () {
    test('returns empty map when key missing', () {
      expect(meshPadApiKeyHeaders(null), isEmpty);
      expect(meshPadApiKeyHeaders(''), isEmpty);
      expect(meshPadApiKeyHeaders('   '), isEmpty);
    });

    test('includes header when key set', () {
      expect(
        meshPadApiKeyHeaders('secret'),
        {meshPadApiKeyHeader: 'secret'},
      );
    });
  });

  group('meshPadApiKeyFromHeaders', () {
    test('reads X-MeshPad-Api-Key', () {
      expect(
        meshPadApiKeyFromHeaders({meshPadApiKeyHeader.toLowerCase(): 'abc'}),
        'abc',
      );
    });

    test('reads Authorization Bearer', () {
      expect(
        meshPadApiKeyFromHeaders({'authorization': 'Bearer token-1'}),
        'token-1',
      );
    });
  });

  group('isMeshPadPublicApiPath', () {
    test('health is public', () {
      expect(isMeshPadPublicApiPath('/api/health'), isTrue);
      expect(isMeshPadPublicApiPath('/api/notes'), isFalse);
    });
  });
}
