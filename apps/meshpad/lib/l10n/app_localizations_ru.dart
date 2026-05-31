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
      'Sidecar на :45839; sync пока через LAN fallback';

  @override
  String get exportNotes => 'Экспорт заметок';

  @override
  String get exportNotesSubtitle => 'Zip-архив notes/ без ключей sync';

  @override
  String get importNotes => 'Импорт заметок';

  @override
  String get importNotesSubtitle => 'Объединение по дате изменения (LWW)';

  @override
  String get verifyData => 'Проверить данные';

  @override
  String get verifyDataSubtitle =>
      'Пересобрать индекс из файлов и создать отсутствующие превью';

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
  String get footerWeb =>
      'Web-клиент подключается к headless-серверу (meshpad_server).';

  @override
  String get footerNative =>
      'Local-first Markdown. Синхронизация между устройствами — LAN (HTTP).';

  @override
  String get devicesDiscoveryHint =>
      'Поиск устройств в локальной сети (mDNS/UDP)';

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
  String get emptyNotePlaceholder => '_Пустая заметка_';
}
