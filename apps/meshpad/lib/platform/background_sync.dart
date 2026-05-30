import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:workmanager/workmanager.dart';

import '../core/storage/app_settings.dart';
import '../core/storage/app_settings_store.dart';

const backgroundSyncTaskName = 'meshpad_background_sync';

@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != backgroundSyncTaskName) return false;

    try {
      final store = AppSettingsStore();
      final settings = await store.loadSettings();
      if (!settings.autoSyncEnabled) return true;

      final dataDir = await store.loadDataDir();
      await runHeadlessMaintenance(dataDir: dataDir);
      return true;
    } catch (_) {
      return false;
    }
  });
}

/// Registers Android WorkManager periodic maintenance/sync (Sprint 5).
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
