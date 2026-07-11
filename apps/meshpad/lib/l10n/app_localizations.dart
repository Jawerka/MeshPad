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

  /// No description provided for @fileSaved.
  ///
  /// In ru, this message translates to:
  /// **'Файл сохранён'**
  String get fileSaved;

  /// No description provided for @fileSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить файл'**
  String get fileSaveFailed;

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

  /// No description provided for @updatesWhatsNew.
  ///
  /// In ru, this message translates to:
  /// **'Что нового'**
  String get updatesWhatsNew;

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

  /// No description provided for @gentleNetworkMode.
  ///
  /// In ru, this message translates to:
  /// **'Щадящий режим сети'**
  String get gentleNetworkMode;

  /// No description provided for @gentleNetworkModeHint.
  ///
  /// In ru, this message translates to:
  /// **'Реже discovery и broadcast — меньше нагрузка на Wi‑Fi'**
  String get gentleNetworkModeHint;

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
  /// **'Эксперимент: sidecar (:45839), wire sync, затем LAN fallback'**
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

  /// No description provided for @autoBackup.
  ///
  /// In ru, this message translates to:
  /// **'Автобэкап'**
  String get autoBackup;

  /// No description provided for @autoBackupOff.
  ///
  /// In ru, this message translates to:
  /// **'Выключен'**
  String get autoBackupOff;

  /// No description provided for @autoBackupEveryHours.
  ///
  /// In ru, this message translates to:
  /// **'Каждые {hours} ч'**
  String autoBackupEveryHours(int hours);

  /// No description provided for @autoBackupNeedDirectory.
  ///
  /// In ru, this message translates to:
  /// **'Укажите папку для zip-архивов'**
  String get autoBackupNeedDirectory;

  /// No description provided for @autoBackupDirectory.
  ///
  /// In ru, this message translates to:
  /// **'Папка бэкапа'**
  String get autoBackupDirectory;

  /// No description provided for @autoBackupDirectoryNone.
  ///
  /// In ru, this message translates to:
  /// **'Не выбрана'**
  String get autoBackupDirectoryNone;

  /// No description provided for @autoBackupPickDirectoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'Папка для бэкапов MeshPad'**
  String get autoBackupPickDirectoryTitle;

  /// No description provided for @autoBackupLastRun.
  ///
  /// In ru, this message translates to:
  /// **'Последний бэкап: {when}'**
  String autoBackupLastRun(String when);

  /// No description provided for @autoBackupNever.
  ///
  /// In ru, this message translates to:
  /// **'Бэкапов ещё не было'**
  String get autoBackupNever;

  /// No description provided for @autoBackupNow.
  ///
  /// In ru, this message translates to:
  /// **'Сделать бэкап сейчас'**
  String get autoBackupNow;

  /// No description provided for @autoBackupNowSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт notes/ в zip в папку бэкапа'**
  String get autoBackupNowSubtitle;

  /// No description provided for @autoBackupDone.
  ///
  /// In ru, this message translates to:
  /// **'Бэкап сохранён ({count} заметок)'**
  String autoBackupDone(int count);

  /// No description provided for @hoursShort.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч'**
  String hoursShort(int hours);

  /// No description provided for @verifyData.
  ///
  /// In ru, this message translates to:
  /// **'Проверить данные'**
  String get verifyData;

  /// No description provided for @verifyDataSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Пересобрать индекс, создать превью и очистить кэш сверх лимита'**
  String get verifyDataSubtitle;

  /// No description provided for @thumbCacheSection.
  ///
  /// In ru, this message translates to:
  /// **'Кэш превью'**
  String get thumbCacheSection;

  /// No description provided for @thumbCacheLimit.
  ///
  /// In ru, this message translates to:
  /// **'Лимит кэша: {mb} МБ'**
  String thumbCacheLimit(int mb);

  /// No description provided for @thumbCacheMb.
  ///
  /// In ru, this message translates to:
  /// **'{mb} МБ'**
  String thumbCacheMb(int mb);

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

  /// No description provided for @updateDownloadInstall.
  ///
  /// In ru, this message translates to:
  /// **'Скачать и установить'**
  String get updateDownloadInstall;

  /// No description provided for @updateDownloading.
  ///
  /// In ru, this message translates to:
  /// **'Скачивание обновления…'**
  String get updateDownloading;

  /// No description provided for @updateDownloadPercent.
  ///
  /// In ru, this message translates to:
  /// **'{percent}%'**
  String updateDownloadPercent(int percent);

  /// No description provided for @updateDownloadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось скачать: {error}'**
  String updateDownloadFailed(String error);

  /// No description provided for @updateInstallFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть установщик'**
  String get updateInstallFailed;

  /// No description provided for @updateInstallUnknownApps.
  ///
  /// In ru, this message translates to:
  /// **'В настройках разрешите установку из этого приложения и снова нажмите «Скачать и установить».'**
  String get updateInstallUnknownApps;

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

  /// No description provided for @devicesManualPeerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Адрес вручную'**
  String get devicesManualPeerTitle;

  /// No description provided for @devicesManualHostLabel.
  ///
  /// In ru, this message translates to:
  /// **'IP или имя хоста'**
  String get devicesManualHostLabel;

  /// No description provided for @devicesManualPortLabel.
  ///
  /// In ru, this message translates to:
  /// **'HTTP порт'**
  String get devicesManualPortLabel;

  /// No description provided for @devicesManualProbe.
  ///
  /// In ru, this message translates to:
  /// **'Проверить'**
  String get devicesManualProbe;

  /// No description provided for @devicesManualProbeOk.
  ///
  /// In ru, this message translates to:
  /// **'Найдено: {name}'**
  String devicesManualProbeOk(String name);

  /// No description provided for @pairingWaitingOn.
  ///
  /// In ru, this message translates to:
  /// **'Отправка подтверждения на {device}…'**
  String pairingWaitingOn(String device);

  /// No description provided for @pairingHostWaiting.
  ///
  /// In ru, this message translates to:
  /// **'Покажите этот PIN или QR на другом устройстве. Сопряжение завершится, когда оно введёт код.'**
  String get pairingHostWaiting;

  /// No description provided for @pairingGuestIntro.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN с экрана другого устройства и нажмите «Подтвердить».'**
  String get pairingGuestIntro;

  /// No description provided for @pairingCompletedWith.
  ///
  /// In ru, this message translates to:
  /// **'Сопряжено с {device}'**
  String pairingCompletedWith(String device);

  /// No description provided for @syncNoTrustedDevices.
  ///
  /// In ru, this message translates to:
  /// **'Нет доверенных устройств'**
  String get syncNoTrustedDevices;

  /// No description provided for @syncPartialDefault.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация частично выполнена — часть устройств недоступна'**
  String get syncPartialDefault;

  /// No description provided for @syncFailedDefault.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация не удалась'**
  String get syncFailedDefault;

  /// No description provided for @syncRejectedInvalidKey.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация отклонена: неверный ключ. Пересопрягите устройства.'**
  String get syncRejectedInvalidKey;

  /// No description provided for @syncRejectedUntrusted.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация отклонена: устройство не доверено.'**
  String get syncRejectedUntrusted;

  /// No description provided for @syncRejectedSignature.
  ///
  /// In ru, this message translates to:
  /// **'Ключ подписи устарел. Пересопрягите устройства.'**
  String get syncRejectedSignature;

  /// No description provided for @syncRejectedClockSkew.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация отклонена: проверьте время на устройствах.'**
  String get syncRejectedClockSkew;

  /// No description provided for @syncRejectedMissingPeerId.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация отклонена: не указано устройство.'**
  String get syncRejectedMissingPeerId;

  /// No description provided for @syncSigningKeyReset.
  ///
  /// In ru, this message translates to:
  /// **'Ключ подписи был сброшен. Пересопрягите все устройства.'**
  String get syncSigningKeyReset;

  /// No description provided for @syncNeedsRePairTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Требуется пересопряжение'**
  String get syncNeedsRePairTooltip;

  /// No description provided for @syncPartialPeers.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировано {succeeded} из {total}; {failed} недоступны или с ошибкой'**
  String syncPartialPeers(int succeeded, int total, int failed);

  /// No description provided for @syncPeerUnreachable.
  ///
  /// In ru, this message translates to:
  /// **'Устройство недоступно в локальной сети'**
  String get syncPeerUnreachable;

  /// No description provided for @signingKeyResetBanner.
  ///
  /// In ru, this message translates to:
  /// **'Ключ подписи был сброшен. Пересопряжите все доверенные устройства.'**
  String get signingKeyResetBanner;

  /// No description provided for @signingKeyResetDismiss.
  ///
  /// In ru, this message translates to:
  /// **'Я пересопряжил все устройства'**
  String get signingKeyResetDismiss;

  /// No description provided for @devicesActionRePair.
  ///
  /// In ru, this message translates to:
  /// **'Пересопряжение'**
  String get devicesActionRePair;

  /// No description provided for @syncConflictCopiesCount.
  ///
  /// In ru, this message translates to:
  /// **'Конфликтные копии: {count}'**
  String syncConflictCopiesCount(int count);

  /// No description provided for @syncDiagnosticsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Диагностика синхронизации'**
  String get syncDiagnosticsTitle;

  /// No description provided for @syncDiagnosticsCopy.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать журнал'**
  String get syncDiagnosticsCopy;

  /// No description provided for @syncDiagnosticsCopied.
  ///
  /// In ru, this message translates to:
  /// **'Журнал синхронизации скопирован'**
  String get syncDiagnosticsCopied;

  /// No description provided for @syncDiagnosticsEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Запусков синхронизации пока нет'**
  String get syncDiagnosticsEmpty;

  /// No description provided for @pairingQrHostHint.
  ///
  /// In ru, this message translates to:
  /// **'Отсканируйте QR на другом устройстве (MeshPad на телефоне)'**
  String get pairingQrHostHint;

  /// No description provided for @pairingScanQr.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать QR'**
  String get pairingScanQr;

  /// No description provided for @pairingQrScanHint.
  ///
  /// In ru, this message translates to:
  /// **'Наведите камеру на QR с экрана устройства-хоста'**
  String get pairingQrScanHint;

  /// No description provided for @pairingQrInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный QR для pairing'**
  String get pairingQrInvalid;

  /// No description provided for @pairingQrPinMismatch.
  ///
  /// In ru, this message translates to:
  /// **'PIN в QR не совпадает с предложением устройства'**
  String get pairingQrPinMismatch;

  /// No description provided for @pairingQrProbeFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подключиться по QR. Проверьте Wi‑Fi.'**
  String get pairingQrProbeFailed;

  /// No description provided for @devicesSheetTitle.
  ///
  /// In ru, this message translates to:
  /// **'Устройства'**
  String get devicesSheetTitle;

  /// No description provided for @devicesTrustedSection.
  ///
  /// In ru, this message translates to:
  /// **'Доверенные'**
  String get devicesTrustedSection;

  /// No description provided for @devicesDiscoveredSection.
  ///
  /// In ru, this message translates to:
  /// **'Обнаруженные'**
  String get devicesDiscoveredSection;

  /// No description provided for @devicesTrustedEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Нет доверенных устройств.\nДобавьте через PIN-pairing.'**
  String get devicesTrustedEmpty;

  /// No description provided for @devicesDiscovering.
  ///
  /// In ru, this message translates to:
  /// **'Поиск устройств в локальной сети…'**
  String get devicesDiscovering;

  /// No description provided for @devicesOnLan.
  ///
  /// In ru, this message translates to:
  /// **'В локальной сети'**
  String get devicesOnLan;

  /// No description provided for @devicesDiscoveredLan.
  ///
  /// In ru, this message translates to:
  /// **'В LAN · {host}:{port}'**
  String devicesDiscoveredLan(String host, int port);

  /// No description provided for @devicesRevokeAllTrusted.
  ///
  /// In ru, this message translates to:
  /// **'Удалить все доверенные'**
  String get devicesRevokeAllTrusted;

  /// No description provided for @devicesRevokeAllTrustedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить все доверенные устройства?'**
  String get devicesRevokeAllTrustedTitle;

  /// No description provided for @devicesRevokeAllTrustedBody.
  ///
  /// In ru, this message translates to:
  /// **'Этот ПК забудет все сопряжённые устройства. Для синхронизации потребуется сопряжение заново.'**
  String get devicesRevokeAllTrustedBody;

  /// No description provided for @devicesRevokeAllTrustedDone.
  ///
  /// In ru, this message translates to:
  /// **'Удалено доверенных устройств: {count}'**
  String devicesRevokeAllTrustedDone(int count);

  /// No description provided for @devicesPinPairing.
  ///
  /// In ru, this message translates to:
  /// **'Сопряжение по PIN'**
  String get devicesPinPairing;

  /// No description provided for @devicesPinShort.
  ///
  /// In ru, this message translates to:
  /// **'PIN'**
  String get devicesPinShort;

  /// No description provided for @devicesThisDevice.
  ///
  /// In ru, this message translates to:
  /// **'Это устройство'**
  String get devicesThisDevice;

  /// No description provided for @devicesThisDeviceLan.
  ///
  /// In ru, this message translates to:
  /// **'Это устройство · LAN {host}:{port}'**
  String devicesThisDeviceLan(String host, int port);

  /// No description provided for @devicesThisDevicePort.
  ///
  /// In ru, this message translates to:
  /// **'Это устройство · порт {port}'**
  String devicesThisDevicePort(int port);

  /// No description provided for @devicesTrustedLan.
  ///
  /// In ru, this message translates to:
  /// **'Доверенное · {host}:{port}'**
  String devicesTrustedLan(String host, int port);

  /// No description provided for @devicesTrustedLanUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Доверенное · LAN неизвестен'**
  String get devicesTrustedLanUnknown;

  /// No description provided for @devicesIconUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Иконка обновлена'**
  String get devicesIconUpdated;

  /// No description provided for @devicesIconUpdatedNamed.
  ///
  /// In ru, this message translates to:
  /// **'Иконка «{name}» обновлена'**
  String devicesIconUpdatedNamed(String name);

  /// No description provided for @devicesLocalNameTitle.
  ///
  /// In ru, this message translates to:
  /// **'Имя этого устройства'**
  String get devicesLocalNameTitle;

  /// No description provided for @devicesLocalNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: Рабочий ПК'**
  String get devicesLocalNameHint;

  /// No description provided for @devicesTrustedRenameHint.
  ///
  /// In ru, this message translates to:
  /// **'Как показывать в списке'**
  String get devicesTrustedRenameHint;

  /// No description provided for @devicesNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get devicesNameLabel;

  /// No description provided for @devicesTrustedRenamed.
  ///
  /// In ru, this message translates to:
  /// **'«{name}» переименовано'**
  String devicesTrustedRenamed(String name);

  /// No description provided for @devicesPeerUnreachable.
  ///
  /// In ru, this message translates to:
  /// **'Устройство недоступно в сети. Проверьте Wi‑Fi и что MeshPad открыт на обоих устройствах.'**
  String get devicesPeerUnreachable;

  /// No description provided for @devicesSyncTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Таймаут синхронизации'**
  String get devicesSyncTimeout;

  /// No description provided for @devicesSyncNotesCount.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировано заметок: {count}'**
  String devicesSyncNotesCount(int count);

  /// No description provided for @devicesSyncCompleted.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизация завершена'**
  String get devicesSyncCompleted;

  /// No description provided for @devicesNoPeersToSync.
  ///
  /// In ru, this message translates to:
  /// **'Нет устройств для синхронизации'**
  String get devicesNoPeersToSync;

  /// No description provided for @devicesPairingTitle.
  ///
  /// In ru, this message translates to:
  /// **'PIN-pairing'**
  String get devicesPairingTitle;

  /// No description provided for @devicesPairingShowPinSelectPeer.
  ///
  /// In ru, this message translates to:
  /// **'Покажите этот PIN на другом устройстве. Выберите устройство ниже для подтверждения.'**
  String get devicesPairingShowPinSelectPeer;

  /// No description provided for @devicesPairingShowPinOnly.
  ///
  /// In ru, this message translates to:
  /// **'Покажите этот PIN на другом устройстве.'**
  String get devicesPairingShowPinOnly;

  /// No description provided for @devicesPairingSelectPeer.
  ///
  /// In ru, this message translates to:
  /// **'Устройство в сети'**
  String get devicesPairingSelectPeer;

  /// No description provided for @devicesRemotePinLabel.
  ///
  /// In ru, this message translates to:
  /// **'PIN другого устройства'**
  String get devicesRemotePinLabel;

  /// No description provided for @devicesRemotePinHint.
  ///
  /// In ru, this message translates to:
  /// **'000000'**
  String get devicesRemotePinHint;

  /// No description provided for @devicesPairingConfirmFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подтвердить PIN. Проверьте устройство в сети.'**
  String get devicesPairingConfirmFailed;

  /// No description provided for @devicesPairingNoDiscovered.
  ///
  /// In ru, this message translates to:
  /// **'Нет обнаруженных устройств. Дождитесь появления в списке «Обнаруженные» или проверьте Wi‑Fi.'**
  String get devicesPairingNoDiscovered;

  /// No description provided for @devicesPairingNeedWifi.
  ///
  /// In ru, this message translates to:
  /// **'Для PIN-pairing оба устройства должны быть в одной Wi‑Fi сети и видны в «Обнаруженные».'**
  String get devicesPairingNeedWifi;

  /// No description provided for @devicesPinInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Введите 6-значный PIN'**
  String get devicesPinInvalid;

  /// No description provided for @devicesActionIcon.
  ///
  /// In ru, this message translates to:
  /// **'Иконка'**
  String get devicesActionIcon;

  /// No description provided for @devicesActionRename.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get devicesActionRename;

  /// No description provided for @devicesActionSync.
  ///
  /// In ru, this message translates to:
  /// **'Синхронизировать'**
  String get devicesActionSync;

  /// No description provided for @devicesActionRevoke.
  ///
  /// In ru, this message translates to:
  /// **'Отозвать доверие'**
  String get devicesActionRevoke;

  /// No description provided for @devicesActionsTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Действия'**
  String get devicesActionsTooltip;

  /// No description provided for @devicesManualErrorEmptyHost.
  ///
  /// In ru, this message translates to:
  /// **'Укажите IP или имя хоста'**
  String get devicesManualErrorEmptyHost;

  /// No description provided for @devicesManualErrorInvalidPort.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный порт'**
  String get devicesManualErrorInvalidPort;

  /// No description provided for @devicesManualErrorUnreachable.
  ///
  /// In ru, this message translates to:
  /// **'Устройство недоступно. Проверьте IP, порт и Wi‑Fi.'**
  String get devicesManualErrorUnreachable;

  /// No description provided for @devicesWebUnsupported.
  ///
  /// In ru, this message translates to:
  /// **'Недоступно в Web-клиенте'**
  String get devicesWebUnsupported;

  /// No description provided for @devicesConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get devicesConfirm;

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

  /// No description provided for @trashEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Очистить корзину'**
  String get trashEmpty;

  /// No description provided for @trashEmptyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Очистить корзину?'**
  String get trashEmptyTitle;

  /// No description provided for @trashEmptyBody.
  ///
  /// In ru, this message translates to:
  /// **'Все заметки в корзине будут удалены без возможности восстановления.'**
  String get trashEmptyBody;

  /// No description provided for @trashEmptyDone.
  ///
  /// In ru, this message translates to:
  /// **'Удалено заметок: {count}'**
  String trashEmptyDone(int count);

  /// No description provided for @noteMenuConflicts.
  ///
  /// In ru, this message translates to:
  /// **'Конфликт версий'**
  String get noteMenuConflicts;

  /// No description provided for @noteConflictBadge.
  ///
  /// In ru, this message translates to:
  /// **'Конфликт'**
  String get noteConflictBadge;

  /// No description provided for @noteConflictTitle.
  ///
  /// In ru, this message translates to:
  /// **'Конфликт версий'**
  String get noteConflictTitle;

  /// No description provided for @noteConflictBody.
  ///
  /// In ru, this message translates to:
  /// **'Другое устройство изменило заметку одновременно. Ваша версия сохранена; копия с устройства лежит отдельно.'**
  String get noteConflictBody;

  /// No description provided for @noteConflictUntitled.
  ///
  /// In ru, this message translates to:
  /// **'Без названия'**
  String get noteConflictUntitled;

  /// No description provided for @noteConflictPreview.
  ///
  /// In ru, this message translates to:
  /// **'Версия с устройства'**
  String get noteConflictPreview;

  /// No description provided for @noteConflictClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get noteConflictClose;

  /// No description provided for @noteConflictUseRemote.
  ///
  /// In ru, this message translates to:
  /// **'Применить эту версию'**
  String get noteConflictUseRemote;

  /// No description provided for @noteConflictKeepMine.
  ///
  /// In ru, this message translates to:
  /// **'Оставить мою версию'**
  String get noteConflictKeepMine;

  /// No description provided for @noteMenuHistory.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get noteMenuHistory;

  /// No description provided for @noteMenuCopyAll.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать всё'**
  String get noteMenuCopyAll;

  /// No description provided for @noteHistoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'История версий'**
  String get noteHistoryTitle;

  /// No description provided for @noteHistoryBody.
  ///
  /// In ru, this message translates to:
  /// **'Снимки сохраняются каждые 10 локальных правок (только текст; вложения не откатываются).'**
  String get noteHistoryBody;

  /// No description provided for @noteHistoryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Снимков пока нет. Продолжайте редактировать — первый снимок появится на ревизии 10.'**
  String get noteHistoryEmpty;

  /// No description provided for @noteHistoryRevision.
  ///
  /// In ru, this message translates to:
  /// **'Ревизия {revision}'**
  String noteHistoryRevision(int revision);

  /// No description provided for @noteHistoryCurrentRevision.
  ///
  /// In ru, this message translates to:
  /// **'Совпадает с текущей ревизией'**
  String get noteHistoryCurrentRevision;

  /// No description provided for @noteHistoryDiffLegend.
  ///
  /// In ru, this message translates to:
  /// **'Различия (− сейчас, + снимок):'**
  String get noteHistoryDiffLegend;

  /// No description provided for @noteHistoryRestore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get noteHistoryRestore;

  /// No description provided for @noteHistoryClose.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get noteHistoryClose;

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
