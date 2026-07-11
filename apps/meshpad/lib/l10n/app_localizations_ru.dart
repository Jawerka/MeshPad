// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'MeshPad';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get fileSaved => 'Файл сохранён';

  @override
  String get fileSaveFailed => 'Не удалось сохранить файл';

  @override
  String get close => 'Закрыть';

  @override
  String get change => 'Сменить';

  @override
  String get reset => 'Сбросить';

  @override
  String get clear => 'Очистить';

  @override
  String get download => 'Скачать';

  @override
  String get defaultAction => 'По умолчанию';

  @override
  String get selectFile => 'Выбрать файл';

  @override
  String get changeDataDirTitle => 'Сменить папку данных?';

  @override
  String changeDataDirBody(String path) {
    return 'Новая папка:\n$path\n\nЗаметки из текущей папки не переносятся автоматически. Скопируйте содержимое вручную, если нужно.';
  }

  @override
  String dataDirChanged(String path) {
    return 'Папка данных: $path';
  }

  @override
  String dataDirChangeFailed(String error) {
    return 'Не удалось сменить папку: $error';
  }

  @override
  String get resetDataDirTitle => 'Вернуть папку по умолчанию?';

  @override
  String get resetDataDirBody =>
      'Приложение снова будет использовать стандартную папку в профиле пользователя.';

  @override
  String get dataDirReset => 'Папка данных сброшена';

  @override
  String get updatesTitle => 'Обновления';

  @override
  String updatesUpToDate(String version) {
    return 'Установлена актуальная версия $version';
  }

  @override
  String updatesAvailable(String version) {
    return 'Доступна версия $version';
  }

  @override
  String get updatesUnavailable => 'Не удалось проверить обновления';

  @override
  String get updatesWhatsNew => 'Что нового';

  @override
  String get purgeOutboxTitle => 'Очистить ошибки sync?';

  @override
  String get purgeOutboxBody =>
      'Записи outbox с исчерпанными повторами будут удалены. Сами заметки на диске не затрагиваются.';

  @override
  String get purgeOutboxNone => 'Нет записей с ошибками sync';

  @override
  String purgeOutboxRemoved(int count) {
    return 'Удалено записей outbox: $count';
  }

  @override
  String indexRebuilt(int count) {
    return 'Индекс пересобран: $count заметок';
  }

  @override
  String errorGeneric(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get deviceNameTitle => 'Имя устройства';

  @override
  String get deviceNameHint => 'Видно другим устройствам в сети';

  @override
  String deviceNameSaved(String name) {
    return 'Имя: $name';
  }

  @override
  String get apiKeyTitle => 'API ключ сервера';

  @override
  String get apiKeyHint => 'Оставьте пустым, если сервер без auth';

  @override
  String get apiKeyNotSet => 'Не задан';

  @override
  String get apiKeyMasked => '••••••••';

  @override
  String get apiKeyRemoved => 'API ключ удалён';

  @override
  String get apiKeySaved => 'API ключ сохранён';

  @override
  String get apiUrlTitle => 'URL сервера MeshPad';

  @override
  String get apiUrlLabel => 'Базовый URL API';

  @override
  String get apiUrlHint => 'http://127.0.0.1:8787';

  @override
  String get exportDialogTitle => 'Экспорт заметок MeshPad';

  @override
  String get importArchiveDialogTitle => 'Архив MeshPad (.zip)';

  @override
  String apiUrlSaved(String url) {
    return 'Сервер: $url';
  }

  @override
  String exportNotesCount(int count) {
    return 'Экспортировано заметок: $count';
  }

  @override
  String get importNotesTitle => 'Импорт заметок?';

  @override
  String get importNotesBody =>
      'Заметки из архива будут объединены с локальными по дате изменения. Папка devices/ (ключи sync) не импортируется.';

  @override
  String importNotesResult(int imported, int updated, int skipped) {
    return 'Импорт: $imported новых, $updated обновлено, $skipped пропущено';
  }

  @override
  String get apiServer => 'Сервер API';

  @override
  String get apiKey => 'API ключ';

  @override
  String get dataFolder => 'Папка данных';

  @override
  String get deviceName => 'Имя устройства';

  @override
  String get devicesAndSync => 'Устройства и синхронизация';

  @override
  String get syncOutboxErrors => 'Ошибки sync в очереди';

  @override
  String syncOutboxErrorsSubtitle(int count) {
    return '$count записей с исчерпанными повторами';
  }

  @override
  String syncSettingsError(String error) {
    return 'Настройки sync: $error';
  }

  @override
  String get autoSync => 'Автосинхронизация';

  @override
  String autoSyncEvery(int minutes) {
    return 'Каждые $minutes мин.';
  }

  @override
  String get autoSyncOff => 'Выключена';

  @override
  String get gentleNetworkMode => 'Щадящий режим сети';

  @override
  String get gentleNetworkModeHint =>
      'Реже discovery и broadcast — меньше нагрузка на Wi‑Fi';

  @override
  String get syncOnlyAllowedWifi => 'Синхронизация только в выбранных Wi‑Fi';

  @override
  String get syncOnlyAllowedWifiHintEmpty => 'Добавьте сеть ниже';

  @override
  String syncOnlyAllowedWifiHintList(String networks) {
    return '$networks';
  }

  @override
  String get addCurrentWifi => 'Добавить текущую Wi‑Fi';

  @override
  String get addWifiManually => 'Ввести имя Wi‑Fi вручную';

  @override
  String get addWifiManuallyTitle => 'Имя Wi‑Fi сети';

  @override
  String get addWifiManuallyLabel => 'SSID';

  @override
  String get addWifiManuallyHint => 'Как в настройках Wi‑Fi Android';

  @override
  String settingsWifiAdded(String ssid) {
    return 'Добавлена Wi‑Fi: $ssid';
  }

  @override
  String settingsWifiAlreadyAdded(String ssid) {
    return 'Уже в списке: $ssid';
  }

  @override
  String get settingsWifiPermissionDenied =>
      'Разрешите доступ к геолокации и Wi‑Fi в диалоге или введите имя сети вручную';

  @override
  String get settingsWifiLocationDisabled =>
      'Включите геолокацию в настройках Android, чтобы определить Wi‑Fi, или введите имя вручную';

  @override
  String get settingsWifiSsidUnavailable =>
      'Не удалось определить текущую Wi‑Fi. Подключитесь к сети или введите имя вручную';

  @override
  String minutesShort(int minutes) {
    return '$minutes мин';
  }

  @override
  String get themeSection => 'Тема';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeSystem => 'Системная';

  @override
  String get localeSection => 'Язык';

  @override
  String get localeRu => 'Русский';

  @override
  String get localeEn => 'English';

  @override
  String get localeSystem => 'Системный';

  @override
  String get syncTransportSection => 'Транспорт sync';

  @override
  String get syncTransportLan => 'LAN (HTTP)';

  @override
  String get syncTransportLibp2p => 'libp2p (эксп.)';

  @override
  String get syncTransportLanHint =>
      'mDNS + HTTP/HTTPS между доверенными устройствами';

  @override
  String get syncTransportLibp2pHint =>
      'Эксперимент: sidecar (:45839), wire sync, затем LAN fallback';

  @override
  String get exportNotes => 'Экспорт заметок';

  @override
  String get exportNotesSubtitle => 'Zip-архив notes/ без ключей sync';

  @override
  String get importNotes => 'Импорт заметок';

  @override
  String get importNotesSubtitle => 'Объединение по дате изменения (LWW)';

  @override
  String get autoBackup => 'Автобэкап';

  @override
  String get autoBackupOff => 'Выключен';

  @override
  String autoBackupEveryHours(int hours) {
    return 'Каждые $hours ч';
  }

  @override
  String get autoBackupNeedDirectory => 'Укажите папку для zip-архивов';

  @override
  String get autoBackupDirectory => 'Папка бэкапа';

  @override
  String get autoBackupDirectoryNone => 'Не выбрана';

  @override
  String get autoBackupPickDirectoryTitle => 'Папка для бэкапов MeshPad';

  @override
  String autoBackupLastRun(String when) {
    return 'Последний бэкап: $when';
  }

  @override
  String get autoBackupNever => 'Бэкапов ещё не было';

  @override
  String get autoBackupNow => 'Сделать бэкап сейчас';

  @override
  String get autoBackupNowSubtitle => 'Экспорт notes/ в zip в папку бэкапа';

  @override
  String autoBackupDone(int count) {
    return 'Бэкап сохранён ($count заметок)';
  }

  @override
  String hoursShort(int hours) {
    return '$hours ч';
  }

  @override
  String get verifyData => 'Проверить данные';

  @override
  String get verifyDataSubtitle =>
      'Пересобрать индекс, создать превью и очистить кэш сверх лимита';

  @override
  String get thumbCacheSection => 'Кэш превью';

  @override
  String thumbCacheLimit(int mb) {
    return 'Лимит кэша: $mb МБ';
  }

  @override
  String thumbCacheMb(int mb) {
    return '$mb МБ';
  }

  @override
  String get about => 'О приложении';

  @override
  String aboutWeb(String version) {
    return 'MeshPad Web · $version';
  }

  @override
  String aboutNative(String version) {
    return 'MeshPad $version · local-first Markdown';
  }

  @override
  String get checkUpdates => 'Проверить обновления';

  @override
  String get updateDownloadInstall => 'Скачать и установить';

  @override
  String get updateDownloading => 'Скачивание обновления…';

  @override
  String updateDownloadPercent(int percent) {
    return '$percent%';
  }

  @override
  String updateDownloadFailed(String error) {
    return 'Не удалось скачать: $error';
  }

  @override
  String get updateInstallFailed => 'Не удалось открыть установщик';

  @override
  String get updateInstallUnknownApps =>
      'В настройках разрешите установку из этого приложения и снова нажмите «Скачать и установить».';

  @override
  String get footerWeb =>
      'Web-клиент подключается к headless-серверу (meshpad_server).';

  @override
  String get footerNative =>
      'Local-first Markdown. Синхронизация между устройствами — LAN (HTTP).';

  @override
  String get devicesDiscoveryHint =>
      'Поиск устройств в локальной сети (mDNS/UDP)';

  @override
  String get devicesManualPeerTitle => 'Адрес вручную';

  @override
  String get devicesManualHostLabel => 'IP или имя хоста';

  @override
  String get devicesManualPortLabel => 'HTTP порт';

  @override
  String get devicesManualProbe => 'Проверить';

  @override
  String devicesManualProbeOk(String name) {
    return 'Найдено: $name';
  }

  @override
  String pairingWaitingOn(String device) {
    return 'Отправка подтверждения на $device…';
  }

  @override
  String get pairingHostWaiting =>
      'Покажите этот PIN или QR на другом устройстве. Сопряжение завершится, когда оно введёт код.';

  @override
  String get pairingGuestIntro =>
      'Введите PIN с экрана другого устройства и нажмите «Подтвердить».';

  @override
  String pairingCompletedWith(String device) {
    return 'Сопряжено с $device';
  }

  @override
  String get syncNoTrustedDevices => 'Нет доверенных устройств';

  @override
  String get syncPartialDefault =>
      'Синхронизация частично выполнена — часть устройств недоступна';

  @override
  String get syncFailedDefault => 'Синхронизация не удалась';

  @override
  String get syncRejectedInvalidKey =>
      'Синхронизация отклонена: неверный ключ. Пересопрягите устройства.';

  @override
  String get syncRejectedUntrusted =>
      'Синхронизация отклонена: устройство не доверено.';

  @override
  String get syncRejectedSignature =>
      'Ключ подписи устарел. Пересопрягите устройства.';

  @override
  String get syncRejectedClockSkew =>
      'Синхронизация отклонена: проверьте время на устройствах.';

  @override
  String get syncRejectedMissingPeerId =>
      'Синхронизация отклонена: не указано устройство.';

  @override
  String get syncSigningKeyReset =>
      'Ключ подписи был сброшен. Пересопрягите все устройства.';

  @override
  String get syncNeedsRePairTooltip => 'Требуется пересопряжение';

  @override
  String syncPartialPeers(int succeeded, int total, int failed) {
    return 'Синхронизировано $succeeded из $total; $failed недоступны или с ошибкой';
  }

  @override
  String get syncPeerUnreachable => 'Устройство недоступно в локальной сети';

  @override
  String get signingKeyResetBanner =>
      'Ключ подписи был сброшен. Пересопряжите все доверенные устройства.';

  @override
  String get signingKeyResetDismiss => 'Я пересопряжил все устройства';

  @override
  String get devicesActionRePair => 'Пересопряжение';

  @override
  String syncConflictCopiesCount(int count) {
    return 'Конфликтные копии: $count';
  }

  @override
  String get syncDiagnosticsTitle => 'Диагностика синхронизации';

  @override
  String get syncDiagnosticsCopy => 'Скопировать журнал';

  @override
  String get syncDiagnosticsCopied => 'Журнал синхронизации скопирован';

  @override
  String get syncDiagnosticsEmpty => 'Запусков синхронизации пока нет';

  @override
  String get pairingQrHostHint =>
      'Отсканируйте QR на другом устройстве (MeshPad на телефоне)';

  @override
  String get pairingQrPreparing => 'Запуск LAN-сервера для QR…';

  @override
  String get pairingScanQr => 'Сканировать QR';

  @override
  String get pairingQrScanHint =>
      'Наведите камеру на QR с экрана устройства-хоста';

  @override
  String get pairingQrInvalid => 'Некорректный QR для pairing';

  @override
  String get pairingQrPinMismatch =>
      'PIN в QR не совпадает с предложением устройства';

  @override
  String get pairingQrProbeFailed =>
      'Не удалось подключиться по QR. Проверьте Wi‑Fi.';

  @override
  String get pairingQrCameraFailed => 'Камера недоступна';

  @override
  String get pairingQrCameraFailedHint =>
      'Разрешите доступ к камере в настройках системы или введите PIN вручную.';

  @override
  String get devicesSheetTitle => 'Устройства';

  @override
  String get devicesTrustedSection => 'Доверенные';

  @override
  String get devicesDiscoveredSection => 'Обнаруженные';

  @override
  String get devicesTrustedEmpty =>
      'Нет доверенных устройств.\nДобавьте через PIN-pairing.';

  @override
  String get devicesDiscovering => 'Поиск устройств в локальной сети…';

  @override
  String get devicesOnLan => 'В локальной сети';

  @override
  String devicesDiscoveredLan(String host, int port) {
    return 'В LAN · $host:$port';
  }

  @override
  String get devicesRevokeAllTrusted => 'Удалить все доверенные';

  @override
  String get devicesRevokeAllTrustedTitle =>
      'Удалить все доверенные устройства?';

  @override
  String get devicesRevokeAllTrustedBody =>
      'Этот ПК забудет все сопряжённые устройства. Для синхронизации потребуется сопряжение заново.';

  @override
  String devicesRevokeAllTrustedDone(int count) {
    return 'Удалено доверенных устройств: $count';
  }

  @override
  String get devicesPinPairing => 'Сопряжение по PIN';

  @override
  String get devicesPinShort => 'PIN';

  @override
  String get devicesThisDevice => 'Это устройство';

  @override
  String devicesThisDeviceLan(String host, int port) {
    return 'Это устройство · LAN $host:$port';
  }

  @override
  String devicesThisDevicePort(int port) {
    return 'Это устройство · порт $port';
  }

  @override
  String devicesTrustedLan(String host, int port) {
    return 'Доверенное · $host:$port';
  }

  @override
  String get devicesTrustedLanUnknown => 'Доверенное · LAN неизвестен';

  @override
  String get devicesIconUpdated => 'Иконка обновлена';

  @override
  String devicesIconUpdatedNamed(String name) {
    return 'Иконка «$name» обновлена';
  }

  @override
  String get devicesLocalNameTitle => 'Имя этого устройства';

  @override
  String get devicesLocalNameHint => 'Например: Рабочий ПК';

  @override
  String get devicesTrustedRenameHint => 'Как показывать в списке';

  @override
  String get devicesNameLabel => 'Имя';

  @override
  String devicesTrustedRenamed(String name) {
    return '«$name» переименовано';
  }

  @override
  String get devicesPeerUnreachable =>
      'Устройство недоступно в сети. Проверьте Wi‑Fi и что MeshPad открыт на обоих устройствах.';

  @override
  String get devicesSyncTimeout => 'Таймаут синхронизации';

  @override
  String devicesSyncNotesCount(int count) {
    return 'Синхронизировано заметок: $count';
  }

  @override
  String get devicesSyncCompleted => 'Синхронизация завершена';

  @override
  String get devicesNoPeersToSync => 'Нет устройств для синхронизации';

  @override
  String get devicesPairingTitle => 'PIN-pairing';

  @override
  String get devicesPairingShowPinSelectPeer =>
      'Покажите этот PIN на другом устройстве. Выберите устройство ниже для подтверждения.';

  @override
  String get devicesPairingShowPinOnly =>
      'Покажите этот PIN на другом устройстве.';

  @override
  String get devicesPairingSelectPeer => 'Устройство в сети';

  @override
  String get devicesRemotePinLabel => 'PIN другого устройства';

  @override
  String get devicesRemotePinHint => '000000';

  @override
  String get devicesPairingConfirmFailed =>
      'Не удалось подтвердить PIN. Проверьте устройство в сети.';

  @override
  String get devicesPairingNoDiscovered =>
      'Нет обнаруженных устройств. Дождитесь появления в списке «Обнаруженные» или проверьте Wi‑Fi.';

  @override
  String get devicesPairingNeedWifi =>
      'Для PIN-pairing оба устройства должны быть в одной Wi‑Fi сети и видны в «Обнаруженные».';

  @override
  String get devicesPinInvalid => 'Введите 6-значный PIN';

  @override
  String get devicesActionIcon => 'Иконка';

  @override
  String get devicesActionRename => 'Переименовать';

  @override
  String get devicesActionSync => 'Синхронизировать';

  @override
  String get devicesActionRevoke => 'Отозвать доверие';

  @override
  String get devicesActionsTooltip => 'Действия';

  @override
  String get devicesManualErrorEmptyHost => 'Укажите IP или имя хоста';

  @override
  String get devicesManualErrorInvalidPort => 'Некорректный порт';

  @override
  String get devicesManualErrorUnreachable =>
      'Устройство недоступно. Проверьте IP, порт и Wi‑Fi.';

  @override
  String get devicesWebUnsupported => 'Недоступно в Web-клиенте';

  @override
  String get devicesConfirm => 'Подтвердить';

  @override
  String get filterAllTags => 'Все';

  @override
  String get noteTagsTitle => 'Теги заметки';

  @override
  String get noteTagsHint => 'работа, идеи (через запятую)';

  @override
  String get noteTagsLabel => 'Теги';

  @override
  String get noteMenuEdit => 'Редактировать';

  @override
  String get noteMenuTags => 'Теги';

  @override
  String get noteMenuTrash => 'В корзину';

  @override
  String get noteMenuRestore => 'Восстановить';

  @override
  String get trashEmpty => 'Очистить корзину';

  @override
  String get trashEmptyTitle => 'Очистить корзину?';

  @override
  String get trashEmptyBody =>
      'Все заметки в корзине будут удалены без возможности восстановления.';

  @override
  String trashEmptyDone(int count) {
    return 'Удалено заметок: $count';
  }

  @override
  String get noteMenuConflicts => 'Конфликт версий';

  @override
  String get noteConflictBadge => 'Конфликт';

  @override
  String get noteConflictTitle => 'Конфликт версий';

  @override
  String get noteConflictBody =>
      'Другое устройство изменило заметку одновременно. Ваша версия сохранена; копия с устройства лежит отдельно.';

  @override
  String get noteConflictUntitled => 'Без названия';

  @override
  String get noteConflictPreview => 'Версия с устройства';

  @override
  String get noteConflictClose => 'Закрыть';

  @override
  String get noteConflictUseRemote => 'Применить эту версию';

  @override
  String get noteConflictKeepMine => 'Оставить мою версию';

  @override
  String get noteMenuHistory => 'История';

  @override
  String get noteMenuCopyAll => 'Скопировать всё';

  @override
  String get noteHistoryTitle => 'История версий';

  @override
  String get noteHistoryBody =>
      'Снимки сохраняются каждые 10 локальных правок (только текст; вложения не откатываются).';

  @override
  String get noteHistoryEmpty =>
      'Снимков пока нет. Продолжайте редактировать — первый снимок появится на ревизии 10.';

  @override
  String noteHistoryRevision(int revision) {
    return 'Ревизия $revision';
  }

  @override
  String get noteHistoryCurrentRevision => 'Совпадает с текущей ревизией';

  @override
  String get noteHistoryDiffLegend => 'Различия (− сейчас, + снимок):';

  @override
  String get noteHistoryRestore => 'Восстановить';

  @override
  String get noteHistoryClose => 'Закрыть';

  @override
  String get emptyNotePlaceholder => '_Пустая заметка_';
}
