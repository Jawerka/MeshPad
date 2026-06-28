/// GitHub OAuth App Client ID for Device Flow.
///
/// Set via `--dart-define=MESHPAD_GITHUB_CLIENT_ID=...` at build time,
/// or paste Client ID in Settings → Git sync.
const kGithubOAuthClientIdFromEnvironment = String.fromEnvironment(
  'MESHPAD_GITHUB_CLIENT_ID',
);

String? resolveGithubOAuthClientId({String? settingsClientId}) {
  final fromSettings = settingsClientId?.trim();
  if (fromSettings != null && fromSettings.isNotEmpty) {
    return fromSettings;
  }
  final fromEnv = kGithubOAuthClientIdFromEnvironment.trim();
  if (fromEnv.isNotEmpty) {
    return fromEnv;
  }
  return null;
}

const githubDeviceFlowScope = 'repo';

const githubDeviceCodeUrl = 'https://github.com/login/device/code';
const githubAccessTokenUrl = 'https://github.com/login/oauth/access_token';
const githubApiUserUrl = 'https://api.github.com/user';
