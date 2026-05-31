import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'MeshPad'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @change.
  ///
  /// In ru, this message translates to:
  /// **'Сменить'**
  String get change;

  /// No description provided for @reset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get reset;

  /// No description provided for @clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clear;

  /// No description provided for @download.
  ///
  /// In ru, this message translates to:
  /// **'Скачать'**
  String get download;

  /// No description provided for @defaultAction.
  ///
  /// In ru, this message translates to:
  /// **'По умолчанию'**
  String get defaultAction;

  /// No description provided for @selectFile.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать файл'**
  String get selectFile;

  /// No description provided for @changeDataDirTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сменить папку данных?'**
  String get changeDataDirTitle;

  /// No description provided for @changeDataDirBody.
  ///
  /// In ru, this message translates to:
  /// **'Новая папка:\n{path}\n\nЗаметки из текущей папки не переносятся автоматически. Скопируйте содержимое вручную, если нужно.'**
  String changeDataDirBody(String path);

  /// No description provided for @dataDirChanged.
  ///
  /// In ru, this message translates to:
  /// **'Папка данных: {path}'**
  String dataDirChanged(String path);

  /// No description provided for @dataDirChangeFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сменить папку: {error}'**
  String dataDirChangeFailed(String error);

  /// No description provided for @resetDataDirTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вернуть папку по умолчанию?'**
  String get resetDataDirTitle;

  /// No description provided for @resetDataDirBody.
  ///
  /// In ru, this message translates to:
  /// **'Приложение снова будет использовать стандартную папку в профиле пользователя.'**
  String get resetDataDirBody;

  /// No description provided for @dataDirReset.
  ///
  /// In ru, this message translates to:
  /// **'Папка данных сброшена'**
  String get dataDirReset;

  /// No description provided for @updatesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Обновления'**
  String get updatesTitle;

  /// No description provided for @updatesUpToDate.
  ///
  /// In ru, this message translates to:
  /// **'Установлена актуальная версия {version}'**
  String updatesUpToDate(String version);

  /// No description provided for @updatesAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Доступна версия {version}'**
  String updatesAvailable(String version);

  /// No description provided for @updatesUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось проверить обновления'**
  String get updatesUnavailable;

  /// No description provided for @purgeOutboxTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очистить ошибки sync?'**
  String get purgeOutboxTitle;

  /// No description provided for @purgeOutboxBody.
  ///
  /// In ru, this message translates to:
  /// **'Записи outbox с исчерпанными повторами будут удалены. Сами заметки на диске не затрагиваются.'**
  String get purgeOutboxBody;

  /// No description provided for @purgeOutboxNone.
  ///
  /// In ru, this message translates to:
  /// **'Нет записей с ошибками sync'**
  String get purgeOutboxNone;

  /// No description provided for @purgeOutboxRemoved.
  ///
  /// In ru, this message translates to:
  /// **'Удалено записей outbox: {count}'**
  String purgeOutboxRemoved(int count);

  /// No description provided for @indexRebuilt.
  ///
  /// In ru, this message translates to:
  /// **'Индекс пересобран: {count} заметок'**
  String indexRebuilt(int count);

  /// No description provided for @errorGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {error}'**
  String errorGeneric(String error);

  /// No description provided for @deviceNameTitle.
  ///
  /// In ru, this message translates to:
  /// **'Имя устройства'**
  String get deviceNameTitle;

  /// No description provided for @deviceNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Видно другим устройствам в сети'**
  String get deviceNameHint;

  /// No description provided for @deviceNameSaved.
  ///
  /// In ru, this message translates to:
  /// **'Имя: {name}'**
  String deviceNameSaved(String name);

  /// No description provided for @apiKeyTitle.
  ///
  /// In ru, this message translates to:
  /// **'API ключ сервера'**
  String get apiKeyTitle;

  /// No description provided for @apiKeyHint.
  ///
  /// In ru, this message translates to:
  /// **'Оставьте пустым, если сервер без auth'**
  String get apiKeyHint;

  /// No description provided for @apiKeyNotSet.
  ///
  /// In ru, this message translates to:
  /// **'Не задан'**
  String get apiKeyNotSet;

  /// No description provided for @apiKeyMasked.
  ///
  /// In ru, this message translates to:
  /// **'••••••••'**
  String get apiKeyMasked;

  /// No description provided for @apiKeyRemoved.
  ///
  /// In ru, this message translates to:
  /// **'API ключ удалён'**
  String get apiKeyRemoved;

  /// No description provided for @apiKeySaved.
  ///
  /// In ru, this message translates to:
  /// **'API ключ сохранён'**
  String get apiKeySaved;

  /// No description provided for @apiUrlTitle.
  ///
  /// In ru, this message translates to:
  /// **'URL сервера MeshPad'**
  String get apiUrlTitle;

  /// No description provided for @apiUrlLabel.
  ///
  /// In ru, this message translates to:
  /// **'Базовый URL API'**
  String get apiUrlLabel;

  /// No description provided for @apiUrlHint.
  ///
  /// In ru, this message translates to:
  /// **'http://127.0.0.1:8787'**
  String get apiUrlHint;

  /// No description provided for @exportDialogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт заметок MeshPad'**
  String get exportDialogTitle;

  /// No description provided for @importArchiveDialogTitle.
  ///
  /// In ru, this message translates to:
  /// **'Архив MeshPad (.zip)'**
  String get importArchiveDialogTitle;

  /// No description provided for @apiUrlSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сервер: {url}'**
  String apiUrlSaved(String url);

  /// No description provided for @exportNotesCount.
  ///
  /// In ru, this message translates to:
  /// **'Экспортировано заметок: {count}'**
  String exportNotesCount(int count);

  /// No description provided for @importNotesTitle.
  ///
  /// In ru, this message translates to:
  /// **'Импорт заметок?'**
  String get importNotesTitle;

  /// No description provided for @importNotesBody.
  ///
  /// In ru, this message translates to:
  /// **'Заметки из архива будут объединены с локальными по дате изменения. Папка devices/ (ключи sync) не импортируется.'**
  String get importNotesBody;

  /// No description provided for @importNotesResult.
  ///
  /// In ru, this message translates to:
  /// **'Импорт: {imported} новых, {updated} обновлено, {skipped} пропущено'**
  String importNotesResult(int imported, int updated, int skipped);

  /// No description provided for @apiServer.
  ///
  /// In ru, this message translates to:
  /// **'Сервер API'**
  String get apiServer;

  /// No description provided for @apiKey.
  ///
  /// In ru, this message translates to:
  /// **'API ключ'**
  String get apiKey;

  /// No description provided for @dataFolder.
  ///
  /// In ru, this message translates to:
  /// **'Папка данных'**
  String get dataFolder;

  /// No description provided for @deviceName.
  ///
  /// In ru, this message translates to:
  /// **'Имя устройства'**
  String get deviceName;

  /// No description provided for @devicesAndSync.
  ///
  /// In ru, this message translates to:
  /// **'Устройства и синхронизация'**
  String get devicesAndSync;

  /// No description provided for @syncOutboxErrors.
  ///
  /// In ru, this message translates to:
  /// **'Ошибки sync в очереди'**
  String get syncOutboxErrors;

  /// No description provided for @syncOutboxErrorsSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'{count} записей с исчерпанными повторами'**
  String syncOutboxErrorsSubtitle(int count);

  /// No description provided for @syncSettingsError.
  ///
  /// In ru, this message translates to:
  /// **'Настройки sync: {error}'**
  String syncSettingsError(String error);

  /// No description provided for @autoSync.
  ///
  /// In ru, this message translates to:
  /// **'Автосинхронизация'**
  String get autoSync;

  /// No description provided for @autoSyncEvery.
  ///
  /// In ru, this message translates to:
  /// **'Каждые {minutes} мин.'**
  String autoSyncEvery(int minutes);

  /// No description provided for @autoSyncOff.
  ///
  /// In ru, this message translates to:
  /// **'Выключена'**
  String get autoSyncOff;

  /// No description provided for @minutesShort.
  ///
  /// In ru, this message translates to:
  /// **'{minutes} мин'**
  String minutesShort(int minutes);

  /// No description provided for @themeSection.
  ///
  /// In ru, this message translates to:
  /// **'Тема'**
  String get themeSection;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системная'**
  String get themeSystem;

  /// No description provided for @localeSection.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get localeSection;

  /// No description provided for @localeRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get localeRu;

  /// No description provided for @localeEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get localeEn;

  /// No description provided for @localeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системный'**
  String get localeSystem;

  /// No description provided for @syncTransportSection.
  ///
  /// In ru, this message translates to:
  /// **'Транспорт sync'**
  String get syncTransportSection;

  /// No description provided for @syncTransportLan.
  ///
  /// In ru, this message translates to:
  /// **'LAN (HTTP)'**
  String get syncTransportLan;

  /// No description provided for @syncTransportLibp2p.
  ///
  /// In ru, this message translates to:
  /// **'libp2p (эксп.)'**
  String get syncTransportLibp2p;

  /// No description provided for @syncTransportLanHint.
  ///
  /// In ru, this message translates to:
  /// **'mDNS + HTTP/HTTPS между доверенными устройствами'**
  String get syncTransportLanHint;

  /// No description provided for @syncTransportLibp2pHint.
  ///
  /// In ru, this message translates to:
  /// **'Sidecar на :45839; sync пока через LAN fallback'**
  String get syncTransportLibp2pHint;

  /// No description provided for @exportNotes.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт заметок'**
  String get exportNotes;

  /// No description provided for @exportNotesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Zip-архив notes/ без ключей sync'**
  String get exportNotesSubtitle;

  /// No description provided for @importNotes.
  ///
  /// In ru, this message translates to:
  /// **'Импорт заметок'**
  String get importNotes;

  /// No description provided for @importNotesSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Объединение по дате изменения (LWW)'**
  String get importNotesSubtitle;

  /// No description provided for @verifyData.
  ///
  /// In ru, this message translates to:
  /// **'Проверить данные'**
  String get verifyData;

  /// No description provided for @verifyDataSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Пересобрать индекс из файлов и создать отсутствующие превью'**
  String get verifyDataSubtitle;

  /// No description provided for @about.
  ///
  /// In ru, this message translates to:
  /// **'О приложении'**
  String get about;

  /// No description provided for @aboutWeb.
  ///
  /// In ru, this message translates to:
  /// **'MeshPad Web · {version}'**
  String aboutWeb(String version);

  /// No description provided for @aboutNative.
  ///
  /// In ru, this message translates to:
  /// **'MeshPad {version} · local-first Markdown'**
  String aboutNative(String version);

  /// No description provided for @checkUpdates.
  ///
  /// In ru, this message translates to:
  /// **'Проверить обновления'**
  String get checkUpdates;

  /// No description provided for @footerWeb.
  ///
  /// In ru, this message translates to:
  /// **'Web-клиент подключается к headless-серверу (meshpad_server).'**
  String get footerWeb;

  /// No description provided for @footerNative.
  ///
  /// In ru, this message translates to:
  /// **'Local-first Markdown. Синхронизация между устройствами — LAN (HTTP).'**
  String get footerNative;

  /// No description provided for @devicesDiscoveryHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск устройств в локальной сети (mDNS/UDP)'**
  String get devicesDiscoveryHint;

  /// No description provided for @filterAllTags.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get filterAllTags;

  /// No description provided for @noteTagsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Теги заметки'**
  String get noteTagsTitle;

  /// No description provided for @noteTagsHint.
  ///
  /// In ru, this message translates to:
  /// **'работа, идеи (через запятую)'**
  String get noteTagsHint;

  /// No description provided for @noteTagsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Теги'**
  String get noteTagsLabel;

  /// No description provided for @noteMenuEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get noteMenuEdit;

  /// No description provided for @noteMenuTags.
  ///
  /// In ru, this message translates to:
  /// **'Теги'**
  String get noteMenuTags;

  /// No description provided for @noteMenuTrash.
  ///
  /// In ru, this message translates to:
  /// **'В корзину'**
  String get noteMenuTrash;

  /// No description provided for @noteMenuRestore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get noteMenuRestore;

  /// No description provided for @emptyNotePlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'_Пустая заметка_'**
  String get emptyNotePlaceholder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
