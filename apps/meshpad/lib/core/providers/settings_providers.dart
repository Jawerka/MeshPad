import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../storage/app_settings.dart';
import '../storage/app_settings_store.dart';
import '../storage/scheduled_notes_backup.dart';
import '../../platform/background_sync.dart';
import '../../platform/wifi_info.dart';
import '../theme/device_icons.dart';
import 'git_sync_providers.dart';
import 'discovery_providers.dart';
import 'network_sync_coordinator.dart';
import 'notes_providers.dart';
import 'sync_loop_provider.dart';
import 'sync_providers.dart';

final settingsControllerProvider = Provider<SettingsController>((ref) {
  return SettingsController(ref);
});

class SettingsController {
  SettingsController(this._ref);

  final Ref _ref;

  AppSettingsStore get _store => _ref.read(appSettingsStoreProvider);

  Future<String?> pickDataDirectory() async {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Выберите папку данных MeshPad',
    );
  }

  Future<String?> pickAutoBackupDirectory({String? dialogTitle}) async {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle ?? 'MeshPad backup folder',
    );
  }

  Future<void> setDataDirectory(String path) async {
    final dir = Directory(path);
    await dir.create(recursive: true);
    await _store.saveDataDir(path);
    _reloadAllDataProviders();
  }

  Future<void> resetDataDirectory() async {
    await _store.clearCustomDataDir();
    _reloadAllDataProviders();
  }

  Future<bool> isCustomDataDir() => _store.isUsingCustomDataDir();

  Future<void> setAutoSyncEnabled(bool enabled) async {
    final current = await _store.loadSettings();
    final next = current.copyWith(autoSyncEnabled: enabled);
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
    await _ref.read(syncLoopProvider).reloadSettings();
    await BackgroundSyncRegistrar.applySettings(next);
  }

  Future<void> setAutoSyncIntervalMinutes(int minutes) async {
    final current = await _store.loadSettings();
    final next = current.copyWith(
      autoSyncIntervalMinutes: AppSettings.clampInterval(minutes),
    );
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
    await _ref.read(syncLoopProvider).reloadSettings();
    await BackgroundSyncRegistrar.applySettings(next);
  }

  Future<void> setNetworkProfile(LanNetworkProfile profile) async {
    final current = await _store.loadSettings();
    if (current.networkProfile == profile) return;

    final defaults = LanNetworkProfileSettings.forProfile(profile);
    final next = current.copyWith(
      networkProfile: profile,
      autoSyncIntervalMinutes: profile == LanNetworkProfile.gentle &&
              current.autoSyncIntervalMinutes <
                  defaults.defaultAutoSyncIntervalMinutes
          ? defaults.defaultAutoSyncIntervalMinutes
          : current.autoSyncIntervalMinutes,
    );

    final discovery = _ref.read(discoveryServiceProvider);
    await discovery.prepareForTransportChange();
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
    _ref.invalidate(syncTransportProvider);
    await _ref.read(syncLoopProvider).reloadSettings();
    await BackgroundSyncRegistrar.applySettings(next);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(discovery.ensureRunning());
    });
  }

  Future<void> setSyncOnlyOnAllowedWifi(bool enabled) async {
    final current = await _store.loadSettings();
    final next = current.copyWith(syncOnlyOnAllowedWifi: enabled);
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
    await _ref.read(networkSyncCoordinatorProvider).start();
  }

  Future<void> addAllowedWifiSsid(String ssid) async {
    final normalized = WifiInfoPlatform.normalizeSsid(ssid);
    if (normalized == null || normalized.isEmpty) return;
    final current = await _store.loadSettings();
    if (current.allowedWifiSsids.contains(normalized)) return;
    final next = current.copyWith(
      allowedWifiSsids: [...current.allowedWifiSsids, normalized],
    );
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
  }

  Future<void> setGitSyncEnabled(bool enabled) async {
    final current = await _store.loadSettings();
    final next = current.copyWith(gitSyncEnabled: enabled);
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
    if (enabled) {
      await _ref.read(gitSyncLoopProvider).start();
    }
  }

  Future<void> setGitRepoUrl(String? url) async {
    final current = await _store.loadSettings();
    final trimmed = url?.trim();
    final next = current.copyWith(
      gitRepoUrl: trimmed == null || trimmed.isEmpty ? null : trimmed,
      clearGitRepoUrl: trimmed == null || trimmed.isEmpty,
    );
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
    _ref.invalidate(gitSyncServiceProvider);
  }

  Future<void> setGithubOAuthClientId(String? clientId) async {
    final current = await _store.loadSettings();
    final trimmed = clientId?.trim();
    final next = current.copyWith(
      githubOAuthClientId: trimmed == null || trimmed.isEmpty ? null : trimmed,
      clearGithubOAuthClientId: trimmed == null || trimmed.isEmpty,
    );
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (kIsWeb) {
      final web = _ref.read(webApiSettingsStoreProvider);
      if ((await web.loadThemeMode()) == mode) return;
      await web.saveThemeMode(mode);
      _ref.invalidate(appSettingsProvider);
      return;
    }
    final current = await _store.loadSettings();
    if (current.themeMode == mode) return;
    await _store.saveSettings(current.copyWith(themeMode: mode));
    _ref.invalidate(appSettingsProvider);
  }

  Future<void> setThumbCacheMaxMb(int mb) async {
    final current = await _store.loadSettings();
    final next = clampThumbCacheMaxMb(mb);
    if (current.thumbCacheMaxMb == next) return;
    await _store.saveSettings(current.copyWith(thumbCacheMaxMb: next));
    _ref.invalidate(appSettingsProvider);
  }

  Future<void> setLocaleMode(AppLocaleMode mode) async {
    if (kIsWeb) {
      final web = _ref.read(webApiSettingsStoreProvider);
      if ((await web.loadLocaleMode()) == mode) return;
      await web.saveLocaleMode(mode);
      _ref.invalidate(appSettingsProvider);
      return;
    }
    final current = await _store.loadSettings();
    if (current.localeMode == mode) return;
    await _store.saveSettings(current.copyWith(localeMode: mode));
    _ref.invalidate(appSettingsProvider);
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    final current = await _store.loadSettings();
    if (current.autoBackupEnabled == enabled) return;
    await _store.saveSettings(current.copyWith(autoBackupEnabled: enabled));
    _ref.invalidate(appSettingsProvider);
  }

  Future<void> setAutoBackupIntervalHours(int hours) async {
    final current = await _store.loadSettings();
    final next = ScheduledNotesBackup.clampIntervalHours(hours);
    if (current.autoBackupIntervalHours == next) return;
    await _store.saveSettings(
      current.copyWith(autoBackupIntervalHours: next),
    );
    _ref.invalidate(appSettingsProvider);
  }

  Future<void> setAutoBackupDirectory(String? path) async {
    final current = await _store.loadSettings();
    final trimmed = path?.trim();
    final next = trimmed == null || trimmed.isEmpty
        ? current.copyWith(clearAutoBackupDirectory: true)
        : current.copyWith(autoBackupDirectory: trimmed);
    if (current.autoBackupDirectory == next.autoBackupDirectory) return;
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
  }

  /// Runs scheduled backup when interval elapsed; updates [autoBackupLastAt].
  Future<int?> runAutoBackupIfDue() async {
    if (kIsWeb) return null;
    final dataDir = await _ref.read(dataDirProvider.future);
    if (dataDir == null) return null;
    final settings = await _store.loadSettings();
    final count = await ScheduledNotesBackup.runIfDue(
      dataDir: dataDir,
      settings: settings,
    );
    if (count == null) return null;
    await _store.saveSettings(
      settings.copyWith(autoBackupLastAt: DateTime.now().toUtc()),
    );
    _ref.invalidate(appSettingsProvider);
    return count;
  }

  Future<int> runAutoBackupNow() async {
    if (kIsWeb) {
      throw UnsupportedError('auto backup is native-only');
    }
    final dataDir = await _ref.read(dataDirProvider.future);
    final settings = await _store.loadSettings();
    final dir = settings.autoBackupDirectory?.trim();
    if (dir == null || dir.isEmpty) {
      throw StateError('auto_backup_directory_not_set');
    }
    final count = await ScheduledNotesBackup.exportToDirectory(
      dataDir: dataDir!,
      backupDirectory: dir,
    );
    await _store.saveSettings(
      settings.copyWith(autoBackupLastAt: DateTime.now().toUtc()),
    );
    _ref.invalidate(appSettingsProvider);
    return count;
  }

  Future<int> exportNotesArchive(String zipPath) async {
    final dataDir = await _ref.read(dataDirProvider.future);
    final paths = MeshPadPaths(dataDir!);
    return NotesArchive.exportToFile(paths: paths, zipPath: zipPath);
  }

  Future<NotesArchiveImportResult> importNotesArchive(String zipPath) async {
    final dataDir = await _ref.read(dataDirProvider.future);
    final paths = MeshPadPaths(dataDir!);
    final result = await NotesArchive.importFromFile(
      paths: paths,
      zipPath: zipPath,
    );
    final settings = await _ref.read(appSettingsProvider.future);
    final repo = await _ref.read(noteRepositoryProvider.future);
    await repo.reconcileFromFilesystem(
      thumbCacheMaxMb: settings.thumbCacheMaxMb,
    );
    _ref.invalidate(notesListProvider);
    _ref.invalidate(searchResultsProvider);
    return result;
  }

  Future<int> rebuildIndex() async {
    final settings = await _ref.read(appSettingsProvider.future);
    final repo = await _ref.read(noteRepositoryProvider.future);
    final stopwatch = Stopwatch()..start();
    final count = await repo.reconcileFromFilesystem(
      thumbCacheMaxMb: settings.thumbCacheMaxMb,
    );
    stopwatch.stop();
    MeshPadLog.metric(
        'reconcile_duration_ms', '${stopwatch.elapsedMilliseconds}');
    MeshPadLog.metric('reconcile_notes', '$count');
    await _ref.read(notesListProvider.notifier).reload();
    _ref.invalidate(outboxCountProvider);
    return count;
  }

  Future<void> setApiBaseUrl(String url) async {
    await _ref.read(webApiSettingsStoreProvider).saveBaseUrl(url);
    _reloadWebProviders();
  }

  Future<void> setApiKey(String? key) async {
    await _ref.read(webApiSettingsStoreProvider).saveApiKey(key);
    _reloadWebProviders();
  }

  Future<void> setLocalDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final store = await _ref.read(deviceStoreProvider.future);
    await store.updateDisplayName(trimmed);
    _ref.invalidate(localIdentityProvider);
    _ref.invalidate(syncEngineProvider);

    final transport = _ref.read(syncTransportProvider);
    final lan = transport.lanAccess;
    if (lan != null) {
      await lan.refreshLocalDisplayName(trimmed);
    }
  }

  Future<void> renameTrustedDevice({
    required String peerId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final store = await _ref.read(deviceStoreProvider.future);
    await store.updateTrustedDeviceName(peerId: peerId, name: trimmed);
    _ref.invalidate(trustedDevicesProvider);
  }

  Future<void> setLocalDeviceIcon(String icon) async {
    final store = await _ref.read(deviceStoreProvider.future);
    await store.updateIcon(normalizeDeviceIcon(icon));
    _ref.invalidate(localIdentityProvider);
  }

  Future<void> setTrustedDeviceIcon({
    required String peerId,
    required String icon,
  }) async {
    final store = await _ref.read(deviceStoreProvider.future);
    await store.updateTrustedDeviceIcon(
      peerId: peerId,
      icon: normalizeDeviceIcon(icon),
    );
    _ref.invalidate(trustedDevicesProvider);
  }

  Future<int> revokeAllTrustedDevices() async {
    final store = await _ref.read(deviceStoreProvider.future);
    final revoked = await store.revokeAllTrusted();
    final lan = _ref.read(syncTransportProvider).lanAccess;
    for (final peerId in revoked) {
      lan?.forgetPeer(peerId);
      _ref.read(discoveredPeersProvider.notifier).remove(peerId);
    }
    _ref.invalidate(trustedDevicesProvider);
    return revoked.length;
  }

  Future<int> purgeExhaustedOutbox() async {
    final repo = await _ref.read(noteRepositoryProvider.future);
    final removed = await repo.purgeExhaustedOutboxEntries(
      maxRetries: OutboxProcessor().maxRetries,
    );
    _ref.invalidate(outboxCountProvider);
    _ref.invalidate(outboxFailedCountProvider);
    _ref.invalidate(pendingSyncNoteIdsProvider);
    return removed;
  }

  void _reloadWebProviders() {
    _ref.invalidate(webApiBaseUrlProvider);
    _ref.invalidate(webApiKeyProvider);
    _ref.invalidate(notesServiceProvider);
    _ref.invalidate(notesListProvider);
    _ref.invalidate(searchResultsProvider);
  }

  void _reloadAllDataProviders() {
    _ref.invalidate(appSettingsProvider);
    _ref.invalidate(dataDirProvider);
    _ref.invalidate(customDataDirProvider);
    _ref.invalidate(noteRepositoryProvider);
    _ref.invalidate(notesListProvider);
    _ref.invalidate(searchResultsProvider);
    _ref.invalidate(outboxCountProvider);
    _ref.invalidate(pendingSyncNoteIdsProvider);
    _ref.invalidate(outboxFailedCountProvider);
    _ref.invalidate(deviceStoreProvider);
    _ref.invalidate(localIdentityProvider);
    _ref.invalidate(trustedDevicesProvider);
    _ref.invalidate(syncEngineProvider);
  }
}
