import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

enum AppThemeMode {
  dark,
  light,
  system,
}

AppThemeMode appThemeModeFromWire(String? raw) {
  return switch (raw) {
    'light' => AppThemeMode.light,
    'system' => AppThemeMode.system,
    _ => AppThemeMode.dark,
  };
}

String appThemeModeToWire(AppThemeMode mode) => switch (mode) {
      AppThemeMode.light => 'light',
      AppThemeMode.system => 'system',
      AppThemeMode.dark => 'dark',
    };

enum AppLocaleMode {
  ru,
  en,
  system,
}

AppLocaleMode appLocaleModeFromWire(String? raw) {
  return switch (raw) {
    'en' => AppLocaleMode.en,
    'ru' => AppLocaleMode.ru,
    'system' => AppLocaleMode.system,
    _ => AppLocaleMode.ru,
  };
}

String appLocaleModeToWire(AppLocaleMode mode) => switch (mode) {
      AppLocaleMode.en => 'en',
      AppLocaleMode.system => 'system',
      AppLocaleMode.ru => 'ru',
    };

/// User preferences stored outside the data directory.
class AppSettings {
  const AppSettings({
    this.dataDir,
    this.autoSyncEnabled = true,
    this.autoSyncIntervalMinutes = 15,
    this.feedSort = NoteSort.createdAt,
    this.syncTransportKind = SyncTransportKind.lan,
    this.themeMode = AppThemeMode.dark,
    this.localeMode = AppLocaleMode.ru,
    this.thumbCacheMaxMb = defaultThumbCacheMaxMb,
    this.autoBackupEnabled = false,
    this.autoBackupIntervalHours = defaultAutoBackupIntervalHours,
    this.autoBackupDirectory,
    this.autoBackupLastAt,
    this.allowedWifiSsids = const [],
    this.syncOnlyOnAllowedWifi = false,
    this.gitSyncEnabled = false,
    this.gitRepoUrl,
    this.gitPullIntervalMinutes = 5,
    this.githubOAuthClientId,
  });

  static const minAutoSyncIntervalMinutes = 5;
  static const maxAutoSyncIntervalMinutes = 120;
  static const defaultAutoBackupIntervalHours = 24;
  static const minAutoBackupIntervalHours = 6;
  static const maxAutoBackupIntervalHours = 168;

  final String? dataDir;
  final bool autoSyncEnabled;
  final int autoSyncIntervalMinutes;
  final NoteSort feedSort;
  final SyncTransportKind syncTransportKind;
  final AppThemeMode themeMode;
  final AppLocaleMode localeMode;
  final int thumbCacheMaxMb;
  final bool autoBackupEnabled;
  final int autoBackupIntervalHours;
  final String? autoBackupDirectory;
  final DateTime? autoBackupLastAt;
  final List<String> allowedWifiSsids;
  final bool syncOnlyOnAllowedWifi;
  final bool gitSyncEnabled;
  final String? gitRepoUrl;
  final int gitPullIntervalMinutes;
  final String? githubOAuthClientId;

  AppSettings copyWith({
    String? dataDir,
    bool clearDataDir = false,
    bool? autoSyncEnabled,
    int? autoSyncIntervalMinutes,
    NoteSort? feedSort,
    SyncTransportKind? syncTransportKind,
    AppThemeMode? themeMode,
    AppLocaleMode? localeMode,
    int? thumbCacheMaxMb,
    bool? autoBackupEnabled,
    int? autoBackupIntervalHours,
    String? autoBackupDirectory,
    bool clearAutoBackupDirectory = false,
    DateTime? autoBackupLastAt,
    bool clearAutoBackupLastAt = false,
    List<String>? allowedWifiSsids,
    bool? syncOnlyOnAllowedWifi,
    bool? gitSyncEnabled,
    String? gitRepoUrl,
    bool clearGitRepoUrl = false,
    int? gitPullIntervalMinutes,
    String? githubOAuthClientId,
    bool clearGithubOAuthClientId = false,
  }) {
    return AppSettings(
      dataDir: clearDataDir ? null : (dataDir ?? this.dataDir),
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      autoSyncIntervalMinutes:
          autoSyncIntervalMinutes ?? this.autoSyncIntervalMinutes,
      feedSort: feedSort ?? this.feedSort,
      syncTransportKind: syncTransportKind ?? this.syncTransportKind,
      themeMode: themeMode ?? this.themeMode,
      localeMode: localeMode ?? this.localeMode,
      thumbCacheMaxMb: thumbCacheMaxMb ?? this.thumbCacheMaxMb,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupIntervalHours: autoBackupIntervalHours != null
          ? _clampBackupIntervalHours(autoBackupIntervalHours)
          : this.autoBackupIntervalHours,
      autoBackupDirectory: clearAutoBackupDirectory
          ? null
          : (autoBackupDirectory ?? this.autoBackupDirectory),
      autoBackupLastAt: clearAutoBackupLastAt
          ? null
          : (autoBackupLastAt ?? this.autoBackupLastAt),
      allowedWifiSsids: allowedWifiSsids ?? this.allowedWifiSsids,
      syncOnlyOnAllowedWifi:
          syncOnlyOnAllowedWifi ?? this.syncOnlyOnAllowedWifi,
      gitSyncEnabled: gitSyncEnabled ?? this.gitSyncEnabled,
      gitRepoUrl: clearGitRepoUrl ? null : (gitRepoUrl ?? this.gitRepoUrl),
      gitPullIntervalMinutes:
          gitPullIntervalMinutes ?? this.gitPullIntervalMinutes,
      githubOAuthClientId: clearGithubOAuthClientId
          ? null
          : (githubOAuthClientId ?? this.githubOAuthClientId),
    );
  }

  factory AppSettings.fromJson(
    Map<String, dynamic> json, {
    required String defaultDataDir,
  }) {
    final customDir = json['data_dir'] as String?;
    final interval = json['auto_sync_interval_minutes'];
    return AppSettings(
      dataDir: customDir == null || customDir.trim().isEmpty
          ? defaultDataDir
          : customDir.trim(),
      autoSyncEnabled: json['auto_sync_enabled'] as bool? ?? true,
      autoSyncIntervalMinutes: _clampInterval(
        interval is int ? interval : int.tryParse('$interval') ?? 15,
      ),
      feedSort: _parseFeedSort(json['feed_sort'] as String?),
      syncTransportKind: syncTransportKindFromWire(
        json['sync_transport'] as String?,
      ),
      themeMode: appThemeModeFromWire(json['theme_mode'] as String?),
      localeMode: appLocaleModeFromWire(json['locale_mode'] as String?),
      thumbCacheMaxMb: clampThumbCacheMaxMb(
        _parseThumbCacheMaxMb(json['thumb_cache_max_mb']),
      ),
      autoBackupEnabled: json['auto_backup_enabled'] as bool? ?? false,
      autoBackupIntervalHours: _clampBackupIntervalHours(
        _parseBackupIntervalHours(json['auto_backup_interval_hours']),
      ),
      autoBackupDirectory: _parseOptionalString(json['auto_backup_directory']),
      autoBackupLastAt: _parseOptionalDate(json['auto_backup_last_at']),
      allowedWifiSsids: _parseStringList(json['allowed_wifi_ssids']),
      syncOnlyOnAllowedWifi: json['sync_only_on_allowed_wifi'] as bool? ?? false,
      gitSyncEnabled: json['git_sync_enabled'] as bool? ?? false,
      gitRepoUrl: _parseOptionalString(json['git_repo_url']),
      gitPullIntervalMinutes: _clampGitPullInterval(
        _parseGitPullMinutes(json['git_pull_interval_minutes']),
      ),
      githubOAuthClientId: _parseOptionalString(json['github_oauth_client_id']),
    );
  }

  Map<String, dynamic> toJson({required String defaultDataDir}) {
    final map = <String, dynamic>{
      'auto_sync_enabled': autoSyncEnabled,
      'auto_sync_interval_minutes': autoSyncIntervalMinutes,
      'feed_sort': feedSort == NoteSort.updatedAt ? 'updated_at' : 'created_at',
      'sync_transport': syncTransportKindToWire(syncTransportKind),
      'theme_mode': appThemeModeToWire(themeMode),
      'locale_mode': appLocaleModeToWire(localeMode),
      'thumb_cache_max_mb': thumbCacheMaxMb,
      'auto_backup_enabled': autoBackupEnabled,
      'auto_backup_interval_hours': autoBackupIntervalHours,
      if (autoBackupDirectory != null && autoBackupDirectory!.isNotEmpty)
        'auto_backup_directory': autoBackupDirectory,
      if (autoBackupLastAt != null)
        'auto_backup_last_at': autoBackupLastAt!.toUtc().toIso8601String(),
      if (allowedWifiSsids.isNotEmpty) 'allowed_wifi_ssids': allowedWifiSsids,
      if (syncOnlyOnAllowedWifi) 'sync_only_on_allowed_wifi': true,
      if (gitSyncEnabled) 'git_sync_enabled': true,
      if (gitRepoUrl != null && gitRepoUrl!.isNotEmpty)
        'git_repo_url': gitRepoUrl,
      if (gitPullIntervalMinutes != 5)
        'git_pull_interval_minutes': gitPullIntervalMinutes,
      if (githubOAuthClientId != null && githubOAuthClientId!.isNotEmpty)
        'github_oauth_client_id': githubOAuthClientId,
    };
    if (dataDir != null && dataDir!.trim().isNotEmpty) {
      final normalizedDefault = defaultDataDir.replaceAll('\\', '/');
      final normalizedCurrent = dataDir!.replaceAll('\\', '/');
      if (normalizedCurrent != normalizedDefault) {
        map['data_dir'] = dataDir;
      }
    }
    return map;
  }

  bool isUsingCustomDataDir(String defaultDataDir) {
    final current = dataDir ?? defaultDataDir;
    return current.replaceAll('\\', '/') !=
        defaultDataDir.replaceAll('\\', '/');
  }

  static int clampInterval(int minutes) {
    return minutes.clamp(minAutoSyncIntervalMinutes, maxAutoSyncIntervalMinutes);
  }

  static int _clampInterval(int minutes) => clampInterval(minutes);

  static NoteSort _parseFeedSort(String? raw) {
    return raw == 'updated_at' ? NoteSort.updatedAt : NoteSort.createdAt;
  }

  static int _parseThumbCacheMaxMb(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse('$raw') ?? defaultThumbCacheMaxMb;
  }

  static int _parseBackupIntervalHours(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse('$raw') ?? defaultAutoBackupIntervalHours;
  }

  static int _clampBackupIntervalHours(int hours) =>
      hours.clamp(minAutoBackupIntervalHours, maxAutoBackupIntervalHours);

  static String? _parseOptionalString(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _parseOptionalDate(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => '$e'.trim()).where((s) => s.isNotEmpty).toList();
  }

  static int _parseGitPullMinutes(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse('$raw') ?? 5;
  }

  static int _clampGitPullInterval(int minutes) => minutes.clamp(1, 120);
}
