/// App semver for UI and update checks (PLAN §11.0.2).
///
/// Must match `version:` in [apps/meshpad/pubspec.yaml] (see `app_version_test.dart`).
/// Release: `.\scripts\read-app-version.ps1` → tag `v<version>`.
const kAppVersion = '0.2.6';

const kGitHubRepo = 'Jawerka/MeshPad';

const kGitHubReleasesLatestUrl =
    'https://api.github.com/repos/Jawerka/MeshPad/releases/latest';

const kGitHubReleasesUrl =
    'https://api.github.com/repos/Jawerka/MeshPad/releases';
