import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meshpad/core/services/update_checker.dart';

void main() {
  test('detects newer remote version', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"latest_version":"0.2.0","download_url":"https://example.com/app"}',
        200,
      );
    });

    final checker = UpdateChecker(client: client);
    final result = await checker.check(currentVersion: '0.1.0');

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.latestVersion, '0.2.0');
    checker.close();
  });

  test('parses windows installer url from manifest', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"latest_version":"0.3.0","download_url":"https://example.com/a.apk",'
        '"windows_installer_url":"https://example.com/setup.exe"}',
        200,
      );
    });

    final checker = UpdateChecker(client: client);
    final result = await checker.check(currentVersion: '0.2.0');

    expect(result.status, UpdateCheckStatus.updateAvailable);
    expect(result.windowsInstallerUrl, 'https://example.com/setup.exe');
    checker.close();
  });

  test('reports up to date for same version', () async {
    final client = MockClient((request) async {
      return http.Response('{"latest_version":"0.1.0"}', 200);
    });

    final checker = UpdateChecker(client: client);
    final result = await checker.check(currentVersion: '0.1.0');

    expect(result.status, UpdateCheckStatus.upToDate);
    checker.close();
  });
}
