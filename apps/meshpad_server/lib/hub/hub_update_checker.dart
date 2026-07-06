import 'dart:convert';

import 'package:http/http.dart' as http;

import 'hub_info.dart';

enum HubUpdateCheckStatus { upToDate, updateAvailable, unavailable }

class HubUpdateCheckResult {
  const HubUpdateCheckResult({
    required this.status,
    this.currentVersion,
    this.latestVersion,
    this.downloadUrl,
    this.whatsNewMarkdown,
    this.message,
  });

  final HubUpdateCheckStatus status;
  final String? currentVersion;
  final String? latestVersion;
  final String? downloadUrl;
  final String? whatsNewMarkdown;
  final String? message;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        if (currentVersion != null) 'current_version': currentVersion,
        if (latestVersion != null) 'latest_version': latestVersion,
        if (downloadUrl != null) 'download_url': downloadUrl,
        if (whatsNewMarkdown != null) 'whats_new_markdown': whatsNewMarkdown,
        if (message != null) 'message': message,
      };
}

class HubUpdateChecker {
  HubUpdateChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<HubUpdateCheckResult> check({
    String currentVersion = kHubVersion,
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
        return HubUpdateCheckResult(
          status: HubUpdateCheckStatus.unavailable,
          currentVersion: currentVersion,
          message: 'Сервер обновлений недоступен (${response.statusCode})',
        );
      }

      final release = jsonDecode(response.body) as Map<String, dynamic>;
      if (release['prerelease'] == true) {
        return HubUpdateCheckResult(
          status: HubUpdateCheckStatus.upToDate,
          currentVersion: currentVersion,
        );
      }

      final tag = release['tag_name'] as String? ?? '';
      final latest = _normalizeTagVersion(tag);
      if (latest.isEmpty) {
        return const HubUpdateCheckResult(
          status: HubUpdateCheckStatus.unavailable,
          message: 'Некорректный ответ GitHub Releases',
        );
      }

      final assets = release['assets'] as List<dynamic>? ?? [];
      final downloadUrl = _findHubLinuxAssetUrl(assets);

      if (!_isAppVersionNewer(latest, currentVersion)) {
        return HubUpdateCheckResult(
          status: HubUpdateCheckStatus.upToDate,
          currentVersion: currentVersion,
          latestVersion: latest,
        );
      }

      final whatsNewMarkdown = await _fetchWhatsNewMarkdown(
        releasesListUrl: releasesListUrl,
        currentVersion: currentVersion,
        latestVersion: latest,
        appVersion: currentVersion,
      );

      return HubUpdateCheckResult(
        status: HubUpdateCheckStatus.updateAvailable,
        currentVersion: currentVersion,
        latestVersion: latest,
        downloadUrl: downloadUrl,
        whatsNewMarkdown: whatsNewMarkdown,
        message: downloadUrl == null
            ? 'Новая версия $latest, но артефакт hub для Linux не найден в релизе'
            : null,
      );
    } catch (e) {
      return HubUpdateCheckResult(
        status: HubUpdateCheckStatus.unavailable,
        currentVersion: currentVersion,
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
      return _collectReleaseNotesMarkdown(
        releases: releases.cast<Map<String, dynamic>>(),
        currentVersion: currentVersion,
        latestVersion: latestVersion,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _githubHeaders(String appVersion) => {
        'User-Agent': 'MeshPad-Hub/$appVersion',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  String? _findHubLinuxAssetUrl(List<dynamic> assets) {
    for (final asset in assets) {
      final map = asset as Map<String, dynamic>;
      final name = map['name'] as String? ?? '';
      if (!name.contains('hub') || !name.contains('linux-x64')) continue;
      final url = map['browser_download_url'] as String?;
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  void close() => _client.close();
}

String _normalizeTagVersion(String tag) {
  final trimmed = tag.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed.substring(1);
  }
  return trimmed;
}

bool _isAppVersionNewer(String remote, String local) =>
    _compareAppVersions(remote, local) > 0;

int _compareAppVersions(String a, String b) {
  final aParts = _parseVersion(a);
  final bParts = _parseVersion(b);
  final length = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < length; i++) {
    final av = i < aParts.length ? aParts[i] : 0;
    final bv = i < bParts.length ? bParts[i] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}

List<int> _parseVersion(String raw) {
  return raw
      .split('+')
      .first
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();
}

String? _collectReleaseNotesMarkdown({
  required List<Map<String, dynamic>> releases,
  required String currentVersion,
  required String latestVersion,
}) {
  final sections = <String>[];

  for (final release in releases) {
    if (release['draft'] == true || release['prerelease'] == true) continue;

    final tag = release['tag_name'] as String? ?? '';
    if (tag.isEmpty) continue;

    final version = _normalizeTagVersion(tag);
    if (!_isAppVersionNewer(version, currentVersion)) continue;
    if (_isAppVersionNewer(version, latestVersion)) continue;

    final body = (release['body'] as String? ?? '').trim();
    if (body.isEmpty || _isAutoGeneratedReleaseBody(body)) continue;

    sections.add('## v$version\n\n$body');
  }

  if (sections.isEmpty) return null;
  return sections.join('\n\n');
}

bool _isAutoGeneratedReleaseBody(String body) {
  final lines = body
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length != 1) return false;
  return lines.first.startsWith('**Full Changelog**:');
}
