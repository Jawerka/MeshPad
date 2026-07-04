/// App semver for UI and update checks (PLAN §11.0.2).
///
/// Must match `version:` in [apps/meshpad/pubspec.yaml] (see `app_version_test.dart`).
/// Release: `.\scripts\read-app-version.ps1` → tag `v<version>`.
const kAppVersion = '0.2.5';

const kVersionManifestUrl =
    'https://raw.githubusercontent.com/Jawerka/MeshPad/main/version.json';
