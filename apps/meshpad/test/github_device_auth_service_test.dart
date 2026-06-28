import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:meshpad/core/constants/github_oauth.dart';
import 'package:meshpad/core/services/github_device_auth_service.dart';

void main() {
  test('requestDeviceCode parses GitHub response', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), githubDeviceCodeUrl);
      return http.Response(
        jsonEncode({
          'device_code': 'dc_test',
          'user_code': 'ABCD-1234',
          'verification_uri': 'https://github.com/login/device',
          'expires_in': 900,
          'interval': 5,
        }),
        200,
      );
    });
    final service = GitHubDeviceAuthService(client: client);
    final code = await service.requestDeviceCode(clientId: 'cid');
    expect(code.userCode, 'ABCD-1234');
    service.close();
  });

  test('pollForAccessToken succeeds after authorization_pending', () async {
    var polls = 0;
    final client = MockClient((request) async {
      if (request.url.toString() == githubAccessTokenUrl) {
        polls++;
        if (polls == 1) {
          return http.Response(
            jsonEncode({'error': 'authorization_pending'}),
            200,
          );
        }
        return http.Response(
          jsonEncode({'access_token': 'gho_test_token'}),
          200,
        );
      }
      if (request.url.toString() == githubApiUserUrl) {
        return http.Response(jsonEncode({'login': 'masny'}), 200);
      }
      return http.Response('not found', 404);
    });

    final service = GitHubDeviceAuthService(
      client: client,
      sleep: (_) async {},
    );
    final session = await service.pollForAccessToken(
      clientId: 'cid',
      deviceCode: const GitHubDeviceCode(
        deviceCode: 'dc',
        userCode: 'X',
        verificationUri: 'https://github.com/login/device',
        expiresIn: 60,
        interval: 1,
      ),
    );
    expect(session.accessToken, 'gho_test_token');
    expect(session.login, 'masny');
    expect(polls, 2);
    service.close();
  });
}
