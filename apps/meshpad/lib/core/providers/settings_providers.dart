import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_settings_store.dart';
import 'notes_providers.dart';
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

  void _reloadAllDataProviders() {
    _ref.invalidate(dataDirProvider);
    _ref.invalidate(customDataDirProvider);
    _ref.invalidate(noteRepositoryProvider);
    _ref.invalidate(notesListProvider);
    _ref.invalidate(searchResultsProvider);
    _ref.invalidate(outboxCountProvider);
    _ref.invalidate(pendingSyncNoteIdsProvider);
    _ref.invalidate(noteSyncStatusesProvider);
    _ref.invalidate(outboxFailedCountProvider);
    _ref.invalidate(deviceStoreProvider);
    _ref.invalidate(localIdentityProvider);
    _ref.invalidate(trustedDevicesProvider);
    _ref.invalidate(syncEngineProvider);
  }
}
