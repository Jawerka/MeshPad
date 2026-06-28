import 'package:meshpad_core/meshpad_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// Web client: persisted MeshPad server base URL and UI preferences.
class WebApiSettingsStore {
  static const defaultBaseUrl = 'http://127.0.0.1:8787';
  static const _baseUrlKey = 'meshpad_api_base_url';
  static const _apiKeyKey = 'meshpad_api_key';
  static const _feedSortKey = 'meshpad_feed_sort';
  static const _themeModeKey = 'meshpad_theme_mode';
  static const _localeModeKey = 'meshpad_locale_mode';

  Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url.trim());
  }

  Future<String?> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_apiKeyKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> saveApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(_apiKeyKey);
    } else {
      await prefs.setString(_apiKeyKey, trimmed);
    }
  }

  Future<NoteSort> loadFeedSort() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_feedSortKey);
    return raw == 'updated_at' ? NoteSort.updatedAt : NoteSort.createdAt;
  }

  Future<void> saveFeedSort(NoteSort sort) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _feedSortKey,
      sort == NoteSort.updatedAt ? 'updated_at' : 'created_at',
    );
  }

  Future<AppThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return appThemeModeFromWire(prefs.getString(_themeModeKey));
  }

  Future<void> saveThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, appThemeModeToWire(mode));
  }

  Future<AppLocaleMode> loadLocaleMode() async {
    final prefs = await SharedPreferences.getInstance();
    return appLocaleModeFromWire(prefs.getString(_localeModeKey));
  }

  Future<void> saveLocaleMode(AppLocaleMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeModeKey, appLocaleModeToWire(mode));
  }

  /// Web UI preferences (PLAN §11.6.5).
  Future<AppSettings> loadAppSettings() async {
    return AppSettings(
      themeMode: await loadThemeMode(),
      localeMode: await loadLocaleMode(),
      feedSort: await loadFeedSort(),
      autoSyncEnabled: false,
    );
  }
}
