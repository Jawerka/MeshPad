import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  Future<String> loadDataDir() async {
    final file = await _settingsFile();
    if (!await file.exists()) {
      return defaultDataDir();
    }

    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final custom = json['data_dir'] as String?;
      if (custom == null || custom.trim().isEmpty) {
        return defaultDataDir();
      }
      return p.normalize(custom.trim());
    } catch (_) {
      return defaultDataDir();
    }
  }

  Future<void> saveDataDir(String path) async {
    final normalized = p.normalize(path.trim());
    final file = await _settingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({'data_dir': normalized}),
    );
  }

  Future<void> clearCustomDataDir() async {
    final file = await _settingsFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> isUsingCustomDataDir() async {
    final current = await loadDataDir();
    final defaultDir = await defaultDataDir();
    return p.normalize(current) != p.normalize(defaultDir);
  }
}
