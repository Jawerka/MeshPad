import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_info.dart';

enum UpdateCheckStatus { upToDate, updateAvailable, unavailable }

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.latestVersion,
    this.downloadUrl,
    this.windowsDownloadUrl,
    this.windowsInstallerUrl,
    this.message,
  });

  final UpdateCheckStatus status;
  final String? latestVersion;
  final String? downloadUrl;
  final String? windowsDownloadUrl;
  final String? windowsInstallerUrl;
  final String? message;
}

class UpdateChecker {
  UpdateChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<UpdateCheckResult> check({
    String currentVersion = kAppVersion,
    String manifestUrl = kVersionManifestUrl,
  }) async {
    try {
      final response = await _client
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.unavailable,
          message: 'Сервер обновлений недоступен (${response.statusCode})',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final latest =
          json['latest_version'] as String? ?? json['version'] as String? ?? '';
      final downloadUrl = json['android_apk_url'] as String? ??
          json['download_url'] as String? ??
          json['url'] as String?;
      final windowsDownloadUrl = json['windows_download_url'] as String?;
      final windowsInstallerUrl = json['windows_installer_url'] as String?;

      if (latest.isEmpty) {
        return const UpdateCheckResult(
          status: UpdateCheckStatus.unavailable,
          message: 'Некорректный манифест версий',
        );
      }

      if (_isNewer(latest, currentVersion)) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.updateAvailable,
          latestVersion: latest,
          downloadUrl: downloadUrl,
          windowsDownloadUrl: windowsDownloadUrl,
          windowsInstallerUrl: windowsInstallerUrl,
        );
      }

      return UpdateCheckResult(status: UpdateCheckStatus.upToDate);
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.unavailable,
        message: e.toString(),
      );
    }
  }

  bool _isNewer(String remote, String local) {
    final remoteParts = _parseVersion(remote);
    final localParts = _parseVersion(local);
    for (var i = 0; i < 3; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final l = i < localParts.length ? localParts[i] : 0;
      if (r != l) return r > l;
    }
    return false;
  }

  List<int> _parseVersion(String raw) {
    return raw
        .split('+')
        .first
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }

  void close() => _client.close();
}
