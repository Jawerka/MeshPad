# Разработка MeshPad

## Требования

| Инструмент | Версия / примечание |
|------------|---------------------|
| Git | 2.x |
| Flutter | stable (см. `.fvmrc`) |
| Dart | идёт с Flutter |
| Android Studio / SDK | только для сборки Android |
| Visual Studio 2022 | «Desktop development with C++» — для `windows` |
| clang/cmake | для `linux` desktop (WSL или нативный Linux) |

## Устранение неполадок

### `Unable to update Dart SDK` / `storage.googleapis.com`

Первый запуск Flutter скачивает Dart SDK с Google CDN. Нужен доступ в интернет (или VPN/прокси). После успешного `flutter doctor` SDK кэшируется локально.

```powershell
$env:Path = "$env:LOCALAPPDATA\flutter\bin;" + $env:Path
flutter doctor -v
```

### Melos не в PATH

```powershell
$env:Path = "$env:LOCALAPPDATA\Pub\Cache\bin;" + $env:Path
dart pub global activate melos
```

## Быстрый старт (Windows)

```powershell
cd D:\Documents\Projects\MeshPad
.\scripts\setup.ps1
.\scripts\bootstrap.ps1
```

`setup.ps1`:

- при отсутствии Flutter клонирует stable в `%LOCALAPPDATA%\flutter`;
- добавляет Flutter в PATH **текущей сессии**;
- запускает `flutter doctor`;
- выполняет `melos bootstrap` (если monorepo уже создан).

## Git

```powershell
git clone <url> MeshPad
cd MeshPad
.\scripts\setup.ps1
```

`local.properties` (пути SDK) в `.gitignore` — не коммитится.

## Android-эмулятор

AVD **MeshPad_API36** (Pixel 7, API 36, Google Play, x86_64).

```powershell
.\scripts\launch-emulator.ps1
# или: flutter emulators --launch MeshPad_API36

cd apps\meshpad
flutter run
```

Другой AVD: Android Studio → Device Manager → Create Virtual Device.

## Запуск приложения

Приложение Flutter — в **`apps/meshpad`**, не в корне репозитория.

```powershell
cd D:\Documents\Projects\MeshPad
.\scripts\run.ps1
```

Или вручную:

```powershell
cd D:\Documents\Projects\MeshPad\apps\meshpad
flutter run -d windows
```

Другие платформы: `.\scripts\run.ps1 -Device chrome` или `-Device android` (эмулятор: `.\scripts\launch-emulator.ps1`).

### Headless HTTP-сервер (Linux / Web backend)

Минимальный REST API для Web-клиента (Sprint 5):

```powershell
.\scripts\run-server.ps1
# или: .\scripts\run-server.ps1 -DataDir D:\MeshPadData -Port 8787 -P2p
```

С флагом `-P2p` сервер участвует в LAN-синхронизации с доверенными устройствами (UDP discovery + HTTP), как desktop-клиент.

Эндпоинты:

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/health` | Проверка доступности |
| GET | `/api/notes` | Список заметок (краткий) |
| GET | `/api/notes/<id>` | Полная заметка |
| POST | `/api/notes` | Создать: `{"markdown":"...", "title":"", "author":""}` |

Данные — тот же каталог `meshpad_core` (`notes/`, Drift-индекс).

### Web-клиент (Flutter web)

Тонкий клиент к API сервера — тот же UI `apps/meshpad`, режим `kIsWeb`:

```powershell
# Терминал 1 — сервер
.\scripts\run-server.ps1

# Терминал 2 — Web UI
cd apps\meshpad
flutter run -d chrome
```

Или одной командой (сервер в фоне): `.\scripts\run-web.ps1`

В настройках Web укажите URL сервера (по умолчанию `http://127.0.0.1:8787`). Поддерживаются лента, создание/редактирование, корзина, поиск, просмотр и **загрузка** вложений на сервер.

Позиция и размер окна (Windows) сохраняются в `%LOCALAPPDATA%\MeshPad\window_state.ini` как физические пиксели `WINDOWPLACEMENT` (v3).

На Windows/Linux при закрытии окна приложение сворачивается в **системный трей** (иконка в области уведомлений). Меню: «Открыть», «Синхронизировать», «Выход». Пока приложение запущено, **автосинхронизация** с доверенными устройствами выполняется по таймеру (настройки → интервал 5–60 мин.).

На **Android** MeshPad появляется в меню «Поделиться» для текста и файлов — создаётся новая заметка в ленте. **WorkManager** периодически пересобирает индекс и очищает корзину (при включённой автосинхронизации, минимум 15 мин.).

Лента подгружает заметки порциями при прокрутке вверх (последние 40 видны сразу). Ошибки sync и сети показываются по-русски через `MeshPadException`.

### Windows: «symlink support» / Developer Mode

Flutter с плагинами (`path_provider`, `sqlite3`) на Windows нужны **симлинки**. Включите **режим разработчика**:

1. `Win + I` → **Конфиденциальность и безопасность** → **Для разработчиков** → **Режим разработчика** — **Вкл.**
2. Или в PowerShell: `start ms-settings:developers`
3. Перезапустите терминал и снова: `.\scripts\run.ps1`

На LTSC/корпоративных образах пункт может быть заблокирован политикой — тогда запускайте Web: `.\scripts\run.ps1 -Device chrome`.

## Тестовый прогон

Локальный аналог CI (codegen → analyze → unit + widget tests):

```powershell
.\scripts\test-run.ps1
```

Опции:

```powershell
.\scripts\test-run.ps1 -SkipBootstrap      # быстрее, если deps уже на месте
.\scripts\test-run.ps1 -WithFormat         # + проверка dart format
.\scripts\test-run.ps1 -WithBuild          # + сборка Windows debug
```

Только analyze + тесты без codegen/bootstrap:

```powershell
dart run melos run check
```

## Команды (после bootstrap)

```powershell
melos run analyze
melos run test
melos run format

cd apps/meshpad
flutter run -d windows
```

## Структура monorepo

- `apps/meshpad` — точка входа Flutter
- `apps/meshpad_server` — headless REST API (Linux / Web backend)
- `packages/meshpad_api_client` — HTTP-клиент для Web
- `packages/meshpad_core` — домен и хранилище (unit-тесты здесь)
- `packages/meshpad_p2p` — сетевой адаптер

## Codegen (Drift)

```powershell
cd packages/meshpad_core
dart run build_runner build --delete-conflicting-outputs
```

## Ручной чеклист (UI-спринт)

- [ ] Создать заметку с заголовком и MD-текстом
- [ ] Прикрепить изображение, открыть лайтбокс (клик мимо — закрыть)
- [ ] Прикрепить большой файл — виден прогресс копирования
- [ ] Настройки → «Проверить данные» после ручного изменения файлов
- [ ] Android: «Поделиться» текстом/фото → новая заметка
- [ ] Удалить в корзину, восстановить
- [ ] Поиск находит фрагмент текста
- [ ] Перезапуск приложения — данные на месте

## CI

Pull request → GitHub Actions: `analyze`, `format`, `test` (см. `.github/workflows/ci.yml`).

## VS Code / Cursor

Рекомендуемые расширения — `.vscode/extensions.json`.
