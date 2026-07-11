/// Hub semver — must match [apps/meshpad/pubspec.yaml] (same release train as clients).
///
/// Release: `.\scripts\read-app-version.ps1` → tag `v<version>`.
const kHubVersion = '0.2.12';

const kGitHubRepo = 'Jawerka/MeshPad';

const kGitHubReleasesLatestUrl =
    'https://api.github.com/repos/Jawerka/MeshPad/releases/latest';

const kGitHubReleasesUrl =
    'https://api.github.com/repos/Jawerka/MeshPad/releases';
