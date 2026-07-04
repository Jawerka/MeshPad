import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/github_oauth.dart';
import '../services/github_device_auth_service.dart';
import 'git_sync_providers.dart';
import 'notes_providers.dart';
import 'secure_storage_providers.dart';

final githubDeviceAuthServiceProvider = Provider<GitHubDeviceAuthService>(
  (ref) {
    final service = GitHubDeviceAuthService();
    ref.onDispose(service.close);
    return service;
  },
);

final githubAuthStateProvider = FutureProvider<GitHubAuthState>((ref) async {
  final store = ref.watch(secureGitTokenStoreProvider);
  final token = await store.read();
  final login = await store.readLogin();
  if (token == null || token.isEmpty) {
    return const GitHubAuthState.disconnected();
  }
  return GitHubAuthState.connected(login: login ?? 'GitHub');
});

class GitHubAuthState {
  const GitHubAuthState._({required this.connected, this.login});

  const GitHubAuthState.disconnected() : this._(connected: false);

  const GitHubAuthState.connected({required String login})
      : this._(connected: true, login: login);

  final bool connected;
  final String? login;
}

final githubAuthControllerProvider = Provider<GitHubAuthController>((ref) {
  return GitHubAuthController(ref);
});

class GitHubAuthController {
  GitHubAuthController(this._ref);

  final Ref _ref;

  Future<String?> resolveClientId() async {
    final settings = await _ref.read(appSettingsProvider.future);
    return resolveGithubOAuthClientId(
      settingsClientId: settings.githubOAuthClientId,
    );
  }

  Future<GitHubDeviceCode> startDeviceFlow() async {
    final clientId = await resolveClientId();
    if (clientId == null || clientId.isEmpty) {
      throw GitHubDeviceAuthException(
        'Укажите GitHub OAuth Client ID в настройках Git sync',
      );
    }
    return _ref.read(githubDeviceAuthServiceProvider).requestDeviceCode(
          clientId: clientId,
        );
  }

  Future<GitHubAuthSession> completeDeviceFlow({
    required GitHubDeviceCode deviceCode,
    void Function(Duration remaining)? onWaiting,
    bool Function()? isCancelled,
  }) async {
    final clientId = await resolveClientId();
    if (clientId == null || clientId.isEmpty) {
      throw GitHubDeviceAuthException('GitHub OAuth Client ID не настроен');
    }
    final session =
        await _ref.read(githubDeviceAuthServiceProvider).pollForAccessToken(
              clientId: clientId,
              deviceCode: deviceCode,
              onWaiting: onWaiting,
              isCancelled: isCancelled,
            );
    await _ref.read(secureGitTokenStoreProvider).writeSession(
          token: session.accessToken,
          login: session.login,
        );
    _ref.invalidate(githubAuthStateProvider);
    _ref.invalidate(gitSyncServiceProvider);
    return session;
  }

  Future<void> signOut() async {
    await _ref.read(secureGitTokenStoreProvider).delete();
    _ref.invalidate(githubAuthStateProvider);
    _ref.invalidate(gitSyncServiceProvider);
  }
}
