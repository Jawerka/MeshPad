import 'package:flutter_test/flutter_test.dart';
import 'package:meshpad/core/storage/app_settings.dart';

void main() {
  test('AppSettings serializes theme_mode', () {
    const settings = AppSettings(themeMode: AppThemeMode.light);
    final json = settings.toJson(defaultDataDir: '/data');
    expect(json['theme_mode'], 'light');

    final restored = AppSettings.fromJson(json, defaultDataDir: '/data');
    expect(restored.themeMode, AppThemeMode.light);
  });

  test('appThemeModeFromWire defaults to dark', () {
    expect(appThemeModeFromWire(null), AppThemeMode.dark);
    expect(appThemeModeFromWire('system'), AppThemeMode.system);
    expect(appThemeModeToWire(AppThemeMode.system), 'system');
  });

  test('AppSettings serializes locale_mode', () {
    const settings = AppSettings(localeMode: AppLocaleMode.en);
    final json = settings.toJson(defaultDataDir: '/data');
    expect(json['locale_mode'], 'en');

    final restored = AppSettings.fromJson(json, defaultDataDir: '/data');
    expect(restored.localeMode, AppLocaleMode.en);
  });

  test('appLocaleModeFromWire defaults to ru', () {
    expect(appLocaleModeFromWire(null), AppLocaleMode.ru);
    expect(appLocaleModeFromWire('system'), AppLocaleMode.system);
    expect(appLocaleModeToWire(AppLocaleMode.system), 'system');
  });
}
