import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshpad/core/services/update_checker.dart';

const _latestRelease = '''
{
  "tag_name": "v0.3.0",
  "prerelease": false,
  "assets": [
    {
      "name": "meshpad-0.3.0.apk",
      "browser_download_url": "https://github.com/example/meshpad-0.3.0.apk"
    },
    {
      "name": "meshpad-0.3.0-windows-x64-setup.exe",
      "browser_download_url": "https://github.com/example/setup.exe"
    },
    {
      "name": "meshpad-0.3.0-windows-x64.zip",
      "browser_download_url": "https://github.com/example/app.zip"
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
    "body": "### Added\\n- Feature C"
  },
  {
    "tag_name": "v0.2.0",
    "prerelease": false,
    "draft": false,
    "body": "### Added\\n- Feature B"
  },
  {
    "tag_name": "v0.1.0",
    "prerelease": false,
    "draft": false,
    "body": "### Added\\n- Feature A"
  }
]
''';

void main() {
  test('detects newer GitHub release and parses assets', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases/latest')) {
        return http.Response(_latestRelease, 200);
      }
      if (request.url.path.endsWith('/releases')) {
        return http.Response(_releasesList, 200);
      }
      return http.Response('not found', 404);
    });

    final checker = UpdateChecker(client: client);
    final result = await checker.check(currentVersion: '0.2.0');

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.latestVersion, '0.3.0');
    expect(result.downloadUrl, 'https://github.com/example/meshpad-0.3.0.apk');
    expect(result.windowsInstallerUrl, 'https://github.com/example/setup.exe');
    expect(result.windowsDownloadUrl, 'https://github.com/example/app.zip');
    expect(result.whatsNewMarkdown, contains('## v0.3.0'));
    expect(result.whatsNewMarkdown, isNot(contains('## v0.2.0')));
    checker.close();
  });

  test('reports up to date for same version', () async {
    final client = MockClient((request) async {
      return http.Response(
        _latestRelease.replaceAll('v0.3.0', 'v0.2.0'),
        200,
      );
    });

    final checker = UpdateChecker(client: client);
    final result = await checker.check(currentVersion: '0.2.0');

    expect(result.status, UpdateCheckStatus.upToDate);
    checker.close();
  });

  test('reports unavailable on non-200 response', () async {
    final client = MockClient((request) async {
      return http.Response('forbidden', 403);
    });

    final checker = UpdateChecker(client: client);
    final result = await checker.check(currentVersion: '0.1.0');

    expect(result.status, UpdateCheckStatus.unavailable);
    checker.close();
  });

  test('sends required GitHub API headers', () async {
    late Map<String, String> headers;
    final client = MockClient((request) async {
      headers = request.headers;
      return http.Response(
        '{"tag_name":"v0.1.0","prerelease":false,"assets":[]}',
        200,
      );
    });

    final checker = UpdateChecker(client: client);
    await checker.check(currentVersion: '0.1.0');

    expect(headers['user-agent'], 'MeshPad/0.1.0');
    expect(headers['accept'], 'application/vnd.github+json');
    expect(headers['x-github-api-version'], '2022-11-28');
    checker.close();
  });
}
