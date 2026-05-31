import 'package:meshpad_core/meshpad_core.dart';

/// User preferences stored outside the data directory.
class AppSettings {
  const AppSettings({
    this.dataDir,
    this.autoSyncEnabled = true,
    this.autoSyncIntervalMinutes = 15,
    this.feedSort = NoteSort.createdAt,
  });

  static const minAutoSyncIntervalMinutes = 5;
  static const maxAutoSyncIntervalMinutes = 120;

  final String? dataDir;
  final bool autoSyncEnabled;
  final int autoSyncIntervalMinutes;
  final NoteSort feedSort;

  AppSettings copyWith({
    String? dataDir,
    bool clearDataDir = false,
    bool? autoSyncEnabled,
    int? autoSyncIntervalMinutes,
    NoteSort? feedSort,
  }) {
    return AppSettings(
      dataDir: clearDataDir ? null : (dataDir ?? this.dataDir),
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      autoSyncIntervalMinutes:
          autoSyncIntervalMinutes ?? this.autoSyncIntervalMinutes,
      feedSort: feedSort ?? this.feedSort,
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
    );
  }

  Map<String, dynamic> toJson({required String defaultDataDir}) {
    final map = <String, dynamic>{
      'auto_sync_enabled': autoSyncEnabled,
      'auto_sync_interval_minutes': autoSyncIntervalMinutes,
      'feed_sort': feedSort == NoteSort.updatedAt ? 'updated_at' : 'created_at',
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
