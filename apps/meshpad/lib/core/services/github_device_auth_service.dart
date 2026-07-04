import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/github_oauth.dart';

class GitHubDeviceCode {
  const GitHubDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;

  factory GitHubDeviceCode.fromJson(Map<String, dynamic> json) {
    return GitHubDeviceCode(
      deviceCode: json['device_code'] as String,
      userCode: json['user_code'] as String,
      verificationUri: json['verification_uri'] as String,
      expiresIn: json['expires_in'] as int? ?? 900,
      interval: json['interval'] as int? ?? 5,
    );
  }
}

class GitHubAuthSession {
  const GitHubAuthSession({
    required this.accessToken,
    required this.login,
  });

  final String accessToken;
  final String login;
}

class GitHubDeviceAuthException implements Exception {
  GitHubDeviceAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// OAuth 2.0 Device Authorization Grant for GitHub (desktop-friendly web login).
class GitHubDeviceAuthService {
  GitHubDeviceAuthService({
    http.Client? client,
    this.sleep = Future.delayed,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Future<void> Function(Duration duration) sleep;

  Future<GitHubDeviceCode> requestDeviceCode({
    required String clientId,
    String scope = githubDeviceFlowScope,
  }) async {
    final response = await _client.post(
      Uri.parse(githubDeviceCodeUrl),
      headers: const {'Accept': 'application/json'},
      body: {
        'client_id': clientId,
        'scope': scope,
      },
    );
    if (response.statusCode != 200) {
      throw GitHubDeviceAuthException(
        'GitHub device code failed (${response.statusCode})',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final error = json['error'] as String?;
    if (error != null) {
      throw GitHubDeviceAuthException(
        json['error_description'] as String? ?? error,
      );
    }
    return GitHubDeviceCode.fromJson(json);
  }

  Future<GitHubAuthSession> pollForAccessToken({
    required String clientId,
    required GitHubDeviceCode deviceCode,
    void Function(Duration remaining)? onWaiting,
    bool Function()? isCancelled,
  }) async {
    final deadline =
        DateTime.now().add(Duration(seconds: deviceCode.expiresIn));
    var interval = Duration(seconds: deviceCode.interval);

    while (DateTime.now().isBefore(deadline)) {
      if (isCancelled?.call() == true) {
        throw GitHubDeviceAuthException('Авторизация отменена');
      }

      onWaiting?.call(deadline.difference(DateTime.now()));

      final response = await _client.post(
        Uri.parse(githubAccessTokenUrl),
        headers: const {'Accept': 'application/json'},
        body: {
          'client_id': clientId,
          'device_code': deviceCode.deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
      );

      if (response.statusCode != 200) {
        throw GitHubDeviceAuthException(
          'GitHub token poll failed (${response.statusCode})',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as String?;
      if (error == null) {
        final token = json['access_token'] as String?;
        if (token == null || token.isEmpty) {
          throw GitHubDeviceAuthException('GitHub не вернул access token');
        }
        final login = await _fetchLogin(token);
        return GitHubAuthSession(accessToken: token, login: login);
      }

      switch (error) {
        case 'authorization_pending':
          break;
        case 'slow_down':
          interval += const Duration(seconds: 5);
          break;
        case 'expired_token':
          throw GitHubDeviceAuthException(
            'Код истёк. Запустите вход снова.',
          );
        case 'access_denied':
          throw GitHubDeviceAuthException('Доступ отклонён на GitHub');
        default:
          throw GitHubDeviceAuthException(
            json['error_description'] as String? ?? error,
          );
      }

      await sleep(interval);
    }

    throw GitHubDeviceAuthException('Время ожидания авторизации истекло');
  }

  Future<String> _fetchLogin(String accessToken) async {
    final response = await _client.get(
      Uri.parse(githubApiUserUrl),
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $accessToken',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    if (response.statusCode != 200) {
      return 'github-user';
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['login'] as String? ?? 'github-user';
  }

  void close() => _client.close();
}
