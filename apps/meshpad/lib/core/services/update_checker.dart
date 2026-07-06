import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_info.dart';
import 'release_notes_collector.dart';

enum UpdateCheckStatus { upToDate, updateAvailable, unavailable }

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.latestVersion,
    this.downloadUrl,
    this.windowsDownloadUrl,
    this.windowsInstallerUrl,
    this.whatsNewMarkdown,
    this.message,
  });

  final UpdateCheckStatus status;
  final String? latestVersion;
  final String? downloadUrl;
  final String? windowsDownloadUrl;
  final String? windowsInstallerUrl;
  final String? whatsNewMarkdown;
  final String? message;
}

class UpdateChecker {
  UpdateChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<UpdateCheckResult> check({
    String currentVersion = kAppVersion,
    String latestReleaseUrl = kGitHubReleasesLatestUrl,
    String releasesListUrl = kGitHubReleasesUrl,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse(latestReleaseUrl),
            headers: _githubHeaders(currentVersion),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.unavailable,
          message: 'Сервер обновлений недоступен (${response.statusCode})',
        );
      }

      final release = jsonDecode(response.body) as Map<String, dynamic>;
      if (release['prerelease'] == true) {
        return const UpdateCheckResult(status: UpdateCheckStatus.upToDate);
      }

      final tag = release['tag_name'] as String? ?? '';
      final latest = normalizeTagVersion(tag);
      if (latest.isEmpty) {
        return const UpdateCheckResult(
          status: UpdateCheckStatus.unavailable,
          message: 'Некорректный ответ GitHub Releases',
        );
      }

      final assets = release['assets'] as List<dynamic>? ?? [];
      final downloadUrl =
          _findAssetUrl(assets, (name) => name.endsWith('.apk'));
      final windowsInstallerUrl = _findAssetUrl(
        assets,
        (name) => name.endsWith('-windows-x64-setup.exe'),
      );
      final windowsDownloadUrl = _findAssetUrl(
        assets,
        (name) => name.endsWith('-windows-x64.zip'),
      );

      if (!isAppVersionNewer(latest, currentVersion)) {
        return const UpdateCheckResult(status: UpdateCheckStatus.upToDate);
      }

      final whatsNewMarkdown = await _fetchWhatsNewMarkdown(
        releasesListUrl: releasesListUrl,
        currentVersion: currentVersion,
        latestVersion: latest,
        appVersion: currentVersion,
      );

      return UpdateCheckResult(
        status: UpdateCheckStatus.updateAvailable,
        latestVersion: latest,
        downloadUrl: downloadUrl,
        windowsDownloadUrl: windowsDownloadUrl,
        windowsInstallerUrl: windowsInstallerUrl,
        whatsNewMarkdown: whatsNewMarkdown,
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.unavailable,
        message: e.toString(),
      );
    }
  }

  Future<String?> _fetchWhatsNewMarkdown({
    required String releasesListUrl,
    required String currentVersion,
    required String latestVersion,
    required String appVersion,
  }) async {
    try {
      final uri = Uri.parse(releasesListUrl).replace(
        queryParameters: {'per_page': '30'},
      );
      final response = await _client
          .get(uri, headers: _githubHeaders(appVersion))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final releases = jsonDecode(response.body) as List<dynamic>;
      return collectReleaseNotesMarkdown(
        releases: releases.cast<Map<String, dynamic>>(),
        currentVersion: currentVersion,
        latestVersion: latestVersion,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _githubHeaders(String appVersion) => {
        'User-Agent': 'MeshPad/$appVersion',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  String? _findAssetUrl(
    List<dynamic> assets,
    bool Function(String name) matches,
  ) {
    for (final asset in assets) {
      final map = asset as Map<String, dynamic>;
      final name = map['name'] as String? ?? '';
      if (!matches(name)) continue;
      final url = map['browser_download_url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  void close() => _client.close();
}
