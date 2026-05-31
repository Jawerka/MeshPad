import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshpad/core/storage/web_api_settings_store.dart';

void main() {
  test('WebApiSettingsStore persists base URL', () async {
    SharedPreferences.setMockInitialValues({});
    final store = WebApiSettingsStore();

    expect(await store.loadBaseUrl(), WebApiSettingsStore.defaultBaseUrl);

    await store.saveBaseUrl('http://localhost:9999');
    expect(await store.loadBaseUrl(), 'http://localhost:9999');
  });

  test('WebApiSettingsStore persists API key', () async {
    SharedPreferences.setMockInitialValues({});
    final store = WebApiSettingsStore();

    expect(await store.loadApiKey(), isNull);
    await store.saveApiKey('secret-key');
    expect(await store.loadApiKey(), 'secret-key');
    await store.saveApiKey(null);
    expect(await store.loadApiKey(), isNull);
  });
}
