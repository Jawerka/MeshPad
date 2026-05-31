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
  });

  static const minAutoSyncIntervalMinutes = 5;
  static const maxAutoSyncIntervalMinutes = 120;

  final String? dataDir;
  final bool autoSyncEnabled;
  final int autoSyncIntervalMinutes;
  final NoteSort feedSort;
  final SyncTransportKind syncTransportKind;
  final AppThemeMode themeMode;
  final AppLocaleMode localeMode;

  AppSettings copyWith({
    String? dataDir,
    bool clearDataDir = false,
    bool? autoSyncEnabled,
    int? autoSyncIntervalMinutes,
    NoteSort? feedSort,
    SyncTransportKind? syncTransportKind,
    AppThemeMode? themeMode,
    AppLocaleMode? localeMode,
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
}
