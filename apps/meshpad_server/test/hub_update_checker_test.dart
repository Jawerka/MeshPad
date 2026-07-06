import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshpad_server/hub/hub_update_checker.dart';
import 'package:test/test.dart';

const _latestRelease = '''
{
  "tag_name": "v0.3.0",
  "prerelease": false,
  "assets": [
    {
      "name": "meshpad-hub-0.3.0-linux-x64",
      "browser_download_url": "https://github.com/example/meshpad-hub-0.3.0-linux-x64"
    }
  ]
}
''';

const _releasesList = '''
[
  {
    "tag_name": "v0.3.0",
    "prerelease": false,
    "draft": false,
    "body": "### Added\\n- Hub update button"
  }
]
''';

void main() {
  test('detects newer hub release and linux asset', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases/latest')) {
        return http.Response(_latestRelease, 200);
      }
      if (request.url.path.endsWith('/releases')) {
        return http.Response(_releasesList, 200);
      }
      return http.Response('not found', 404);
    });

    final checker = HubUpdateChecker(client: client);
    final result = await checker.check(currentVersion: '0.2.0');

    expect(result.status, HubUpdateCheckStatus.updateAvailable);
    expect(result.latestVersion, '0.3.0');
    expect(
      result.downloadUrl,
      'https://github.com/example/meshpad-hub-0.3.0-linux-x64',
    );
    expect(result.whatsNewMarkdown, contains('## v0.3.0'));
    checker.close();
  });

  test('reports up to date for same version', () async {
    final client = MockClient((request) async {
      return http.Response(
        _latestRelease.replaceAll('v0.3.0', 'v0.2.0'),
        200,
      );
    });

    final checker = HubUpdateChecker(client: client);
    final result = await checker.check(currentVersion: '0.2.0');

    expect(result.status, HubUpdateCheckStatus.upToDate);
    checker.close();
  });
}
