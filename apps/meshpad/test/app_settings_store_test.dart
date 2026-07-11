import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/storage/app_settings.dart';
import 'package:meshpad/core/storage/app_settings_store.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late AppSettingsStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('meshpad_settings_');
    store = AppSettingsStore(
      settingsFile: () async => File(p.join(tempDir.path, 'app_settings.json')),
      defaultDataDir: () async => p.join(tempDir.path, 'default_meshpad'),
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('loadSettings returns defaults when file missing', () async {
    final settings = await store.loadSettings();
    expect(settings.dataDir, p.join(tempDir.path, 'default_meshpad'));
    expect(settings.autoSyncEnabled, isTrue);
    expect(settings.autoSyncIntervalMinutes, 15);
    expect(settings.feedSort, NoteSort.createdAt);
    expect(settings.syncTransportKind, SyncTransportKind.lan);
  });

  test('saveDataDir persists custom path', () async {
    final custom = p.join(tempDir.path, 'custom_notes');
    await store.saveDataDir(custom);

    expect(await store.loadDataDir(), p.normalize(custom));
    expect(await store.isUsingCustomDataDir(), isTrue);
  });

  test('saveSettings persists auto backup options', () async {
    final lastAt = DateTime.utc(2026, 6, 1, 8);
    await store.saveSettings(
      AppSettings(
        dataDir: await store.defaultDataDir(),
        autoBackupEnabled: true,
        autoBackupIntervalHours: 48,
        autoBackupDirectory: p.join(tempDir.path, 'backups'),
        autoBackupLastAt: lastAt,
      ),
    );

    final loaded = await store.loadSettings();
    expect(loaded.autoBackupEnabled, isTrue);
    expect(loaded.autoBackupIntervalHours, 48);
    expect(loaded.autoBackupDirectory, p.join(tempDir.path, 'backups'));
    expect(loaded.autoBackupLastAt, lastAt);
  });

  test('saveSettings persists auto sync options', () async {
    await store.saveSettings(
      AppSettings(
        dataDir: await store.defaultDataDir(),
        autoSyncEnabled: false,
        autoSyncIntervalMinutes: 30,
      ),
    );

    final loaded = await store.loadSettings();
    expect(loaded.autoSyncEnabled, isFalse);
    expect(loaded.autoSyncIntervalMinutes, 30);
  });

  test('clearCustomDataDir restores default path', () async {
    await store.saveDataDir(p.join(tempDir.path, 'custom_notes'));
    await store.clearCustomDataDir();

    expect(await store.isUsingCustomDataDir(), isFalse);
    expect(await store.loadDataDir(), p.join(tempDir.path, 'default_meshpad'));
  });

  test('AppSettings clamps sync interval', () {
    expect(AppSettings.clampInterval(1), 5);
    expect(AppSettings.clampInterval(200), 120);
    expect(AppSettings.clampInterval(15), 15);
  });

  test('loadSettings removes invalid Wi‑Fi SSIDs from allow-list', () async {
    final file = File(p.join(tempDir.path, 'app_settings.json'));
    await file.writeAsString('''
{
  "allowed_wifi_ssids": ["wifi-2ghz", "<unknown ssid>", "unknown ssid"],
  "sync_only_on_allowed_wifi": true
}
''');

    final loaded = await store.loadSettings();
    expect(loaded.allowedWifiSsids, ['wifi-2ghz']);

    final persisted =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(persisted['allowed_wifi_ssids'], ['wifi-2ghz']);
  });

  test('loadSettings migrates sync_transport libp2p to lan', () async {
    final file = File(p.join(tempDir.path, 'app_settings.json'));
    await file.writeAsString('''
{
  "sync_transport": "libp2p",
  "auto_sync_enabled": true,
  "auto_sync_interval_minutes": 15
}
''');

    final loaded = await store.loadSettings();
    expect(loaded.syncTransportKind, SyncTransportKind.lan);

    final persisted =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(persisted['sync_transport'], 'lan');
  });
}
