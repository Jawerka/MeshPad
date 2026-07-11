import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:workmanager/workmanager.dart';

import '../core/storage/app_settings.dart';
import '../core/storage/app_settings_store.dart';
import '../core/storage/android_tls_root.dart';

const backgroundSyncTaskName = 'meshpad_background_sync';

@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != backgroundSyncTaskName) return false;

    try {
      if (Platform.isAndroid) {
        await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      }

      final store = AppSettingsStore();
      final settings = await store.loadSettings();
      if (!settings.autoSyncEnabled) return true;

      final dataDir = await store.loadDataDir();
      MeshPadLog.configure(logFilePath: p.join(dataDir, 'meshpad.log'));
      await runBackgroundSyncPass(
        dataDir: dataDir,
        getTlsRoot: resolveTlsRoot,
      );
      return true;
    } catch (e, stack) {
      MeshPadLog.warn('sync', 'background sync failed: $e\n$stack');
      return false;
    }
  });
}

/// Registers Android WorkManager periodic maintenance/sync (Sprint 5, C.4 LAN).
class BackgroundSyncRegistrar {
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<void> initialize() async {
    if (!isSupported) return;
    await Workmanager().initialize(backgroundSyncDispatcher);
  }

  static Future<void> applySettings(AppSettings settings) async {
    if (!isSupported) return;

    await Workmanager().cancelByUniqueName(backgroundSyncTaskName);
    if (!settings.autoSyncEnabled) return;

    // Android minimum periodic interval is 15 minutes.
    final minutes = settings.autoSyncIntervalMinutes.clamp(15, 120);

    await Workmanager().registerPeriodicTask(
      backgroundSyncTaskName,
      backgroundSyncTaskName,
      frequency: Duration(minutes: minutes),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
