import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../storage/app_settings.dart';
import '../storage/app_settings_store.dart';
import '../../platform/background_sync.dart';
import '../theme/device_icons.dart';
import 'discovery_providers.dart';
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

  Future<void> setSyncTransportKind(SyncTransportKind kind) async {
    final current = await _store.loadSettings();
    if (current.syncTransportKind == kind) return;
    final discovery = _ref.read(discoveryServiceProvider);
    await discovery.prepareForTransportChange();
    final next = current.copyWith(syncTransportKind: kind);
    await _store.saveSettings(next);
    _ref.invalidate(appSettingsProvider);
    _ref.invalidate(syncTransportProvider);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(discovery.ensureRunning());
    });
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final current = await _store.loadSettings();
    if (current.themeMode == mode) return;
    await _store.saveSettings(current.copyWith(themeMode: mode));
    _ref.invalidate(appSettingsProvider);
  }

  Future<void> setLocaleMode(AppLocaleMode mode) async {
    final current = await _store.loadSettings();
    if (current.localeMode == mode) return;
    await _store.saveSettings(current.copyWith(localeMode: mode));
    _ref.invalidate(appSettingsProvider);
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
    final repo = await _ref.read(noteRepositoryProvider.future);
    await repo.reconcileFromFilesystem();
    _ref.invalidate(notesListProvider);
    _ref.invalidate(searchResultsProvider);
    return result;
  }

  Future<int> rebuildIndex() async {
    final repo = await _ref.read(noteRepositoryProvider.future);
    final count = await repo.reconcileFromFilesystem();
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
