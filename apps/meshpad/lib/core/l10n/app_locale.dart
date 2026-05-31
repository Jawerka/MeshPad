import 'package:flutter/material.dart';

import '../storage/app_settings.dart';

Locale? resolveAppLocale(AppLocaleMode mode) {
  return switch (mode) {
    AppLocaleMode.ru => const Locale('ru'),
    AppLocaleMode.en => const Locale('en'),
    AppLocaleMode.system => null,
  };
}

Locale resolveEffectiveLocale({
  required AppLocaleMode mode,
  required Locale? platformLocale,
  required Iterable<Locale> supportedLocales,
}) {
  final explicit = resolveAppLocale(mode);
  if (explicit != null) return explicit;

  if (platformLocale != null) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == platformLocale.languageCode) {
        return supported;
      }
    }
  }
  return const Locale('ru');
}

String dateFormattingLocaleFor(AppLocaleMode mode, Locale? platformLocale) {
  final code = resolveEffectiveLocale(
    mode: mode,
    platformLocale: platformLocale,
    supportedLocales: const [Locale('ru'), Locale('en')],
  ).languageCode;
  return code == 'en' ? 'en' : 'ru';
}
