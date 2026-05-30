import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/storage/app_settings_store.dart';
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

  test('loadDataDir returns default when settings missing', () async {
    expect(await store.loadDataDir(), p.join(tempDir.path, 'default_meshpad'));
  });

  test('saveDataDir persists custom path', () async {
    final custom = p.join(tempDir.path, 'custom_notes');
    await store.saveDataDir(custom);

    expect(await store.loadDataDir(), p.normalize(custom));
    expect(await store.isUsingCustomDataDir(), isTrue);
  });

  test('clearCustomDataDir restores default', () async {
    await store.saveDataDir(p.join(tempDir.path, 'custom_notes'));
    await store.clearCustomDataDir();

    expect(await store.isUsingCustomDataDir(), isFalse);
    expect(await store.loadDataDir(), p.join(tempDir.path, 'default_meshpad'));
  });
}
