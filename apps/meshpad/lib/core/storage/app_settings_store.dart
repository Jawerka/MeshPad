import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:meshpad_p2p/meshpad_p2p.dart';

import 'app_settings.dart';
import '../../platform/wifi_info.dart';

/// Persists app preferences outside the data directory (so path can be relocated).
class AppSettingsStore {
  AppSettingsStore({
    Future<File> Function()? settingsFile,
    Future<String> Function()? defaultDataDir,
  })  : _settingsFile = settingsFile ?? _defaultSettingsFile,
        _defaultDataDir = defaultDataDir ?? _defaultDataDirPath;

  static const _settingsFileName = 'app_settings.json';

  final Future<File> Function() _settingsFile;
  final Future<String> Function() _defaultDataDir;

  static Future<File> _defaultSettingsFile() async {
    if (Platform.isWindows) {
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        final dir = Directory(p.join(local, 'MeshPad'));
        await dir.create(recursive: true);
        return File(p.join(dir.path, _settingsFileName));
      }
    }

    final support = await getApplicationSupportDirectory();
    return File(p.join(support.path, _settingsFileName));
  }

  static Future<String> _defaultDataDirPath() async {
    final support = await getApplicationSupportDirectory();
    return p.normalize(p.join(support.path, 'meshpad'));
  }

  Future<String> defaultDataDir() => _defaultDataDir();

  Future<AppSettings> loadSettings() async {
    final defaultDir = await defaultDataDir();
    final file = await _settingsFile();
    if (!await file.exists()) {
      return AppSettings(dataDir: defaultDir);
    }

    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final settings = AppSettings.fromJson(json, defaultDataDir: defaultDir);
      final cleaned =
          WifiInfoPlatform.sanitizeAllowedWifiSsids(settings.allowedWifiSsids);
      final needsWifiCleanup = !_listsEqual(cleaned, settings.allowedWifiSsids);
      final sanitized = needsWifiCleanup
          ? settings.copyWith(allowedWifiSsids: cleaned)
          : settings;
      // ADR 0003: libp2p removed — migrate to LAN.
      if (json['sync_transport'] == 'libp2p' ||
          sanitized.syncTransportKind == SyncTransportKind.libp2p) {
        final migrated =
            sanitized.copyWith(syncTransportKind: SyncTransportKind.lan);
        await saveSettings(migrated);
        return migrated;
      }
      if (needsWifiCleanup) {
        await saveSettings(sanitized);
      }
      return sanitized;
    } catch (_) {
      return AppSettings(dataDir: defaultDir);
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final defaultDir = await defaultDataDir();
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        settings.toJson(defaultDataDir: defaultDir),
      ),
    );
  }

  Future<String> loadDataDir() async {
    final settings = await loadSettings();
    return p.normalize(settings.dataDir ?? await defaultDataDir());
  }

  Future<void> saveDataDir(String path) async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(dataDir: p.normalize(path.trim())));
  }

  Future<void> clearCustomDataDir() async {
    final current = await loadSettings();
    await saveSettings(current.copyWith(clearDataDir: true));
  }

  Future<bool> isUsingCustomDataDir() async {
    final settings = await loadSettings();
    return settings.isUsingCustomDataDir(await defaultDataDir());
  }

  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
