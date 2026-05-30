import 'package:shared_preferences/shared_preferences.dart';

/// Web client: persisted MeshPad server base URL.
class WebApiSettingsStore {
  static const defaultBaseUrl = 'http://127.0.0.1:8787';
  static const _key = 'meshpad_api_base_url';

  Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? defaultBaseUrl;
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, url.trim());
  }
}
