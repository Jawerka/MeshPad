# Разработка MeshPad

MVP **0.1.0**. Поведение приложения — [PLAN.md §5](../PLAN.md#5-реализованное-mvp-010). Архитектура — [ARCHITECTURE.md](ARCHITECTURE.md).

## Требования

| Инструмент | Версия / примечание |
|------------|---------------------|
| Git | 2.x |
| Flutter | stable (см. `.fvmrc`) |
| Dart | идёт с Flutter |
| Android Studio / SDK | для Android |
| Visual Studio 2022 | C++ workload — для `windows` |
| clang/cmake | для `linux` desktop |

## Быстрый старт

```powershell
cd D:\Documents\Projects\MeshPad
.\scripts\setup.ps1
.\scripts\bootstrap.ps1
.\scripts\run.ps1
```

## Запуск

| Цель | Команда |
|------|---------|
| Windows | `.\scripts\run.ps1 -Device windows` |
| Android | `.\scripts\launch-emulator.ps1` → `.\scripts\run.ps1 -Device android` |
| Dual (Win+Android) | `.\scripts\run.ps1 -Device dual` |
| Web | `.\scripts\run-web.ps1` |
| Headless server | `.\scripts\run-server.ps1` или `-P2p` для LAN sync |

После изменений native-плагинов (video_player_win, audioplayers):

```powershell
cd apps\meshpad
flutter clean
flutter run -d windows
```

## Headless HTTP API

| Метод | Путь | Описание |
|-------|------|----------|
| GET | `/api/health` | Проверка |
| GET | `/api/notes` | Список; `?sort=`, `?offset=`, `?limit=` |
| GET | `/api/notes/count` | `{ "count": N }` |
| GET | `/api/notes/<id>` | Полная заметка |
| POST | `/api/notes` | Создать |
| PUT | `/api/notes/<id>` | Обновить |
| PUT | `/api/notes/<id>/attachments/<name>` | Загрузить вложение |
| DELETE | `/api/notes/<id>` | В корзину |
| POST | `/api/notes/<id>/restore` | Восстановить |
| GET | `/api/trash` | Корзина |
| GET | `/api/search?q=` | FTS |
| GET | `/api/notes/<id>/attachments/<name>` | Файл |

## Поведение MVP (кратко)

### UI

- Навигация **только через шапку** (sidebar из `ref/` не используется).
- Sync и корзина — в шапке; sync-иконка вращается при активной синхронизации.
- На карточках заметок **нет** иконок sync.

### Sync

- LAN: mDNS + UDP + HTTP; pairing **только PIN**.
- Auto-sync: debounce после правок + таймер 15–60 мин (настройки).
- Android WorkManager: reconcile + purge (мин. интервал 15 мин).

### Данные

- FS — источник истины; «Проверить данные» → reconcile + rebuild `.thumbs/`.
- Корзина: 7 дней, purge при sync tick и maintenance.

### Платформы

- **Windows:** tray, `nuget.config`, видео-постер (`video_player_win`).
- **Web:** thin client; sort в SharedPreferences; вложения через URL.

Окно Windows: `%LOCALAPPDATA%\MeshPad\window_state.ini`.

## Тестовый прогон

```powershell
dart run melos run check
# или
.\scripts\test-run.ps1
```

## Monorepo

- `apps/meshpad` — Flutter UI
- `apps/meshpad_server` — REST + `--p2p`
- `packages/meshpad_core` — домен, FS, Drift, sync, thumbnails
- `packages/meshpad_p2p` — LAN transport
- `packages/meshpad_api_client` — HTTP для Web

## Codegen (Drift)

```powershell
cd packages/meshpad_core
dart run build_runner build --delete-conflicting-outputs
```

## Устранение неполадок

### Flutter / Melos

```powershell
$env:Path = "$env:LOCALAPPDATA\flutter\bin;" + $env:Path
flutter doctor -v
dart pub global activate melos
```

### Windows Developer Mode

Нужен для symlink support плагинов: `start ms-settings:developers` → режим разработчика.

### LAN sync не работает

1. Оба устройства в одной Wi‑Fi.
2. Firewall: `.\scripts\allow-meshpad-firewall.ps1`
3. PIN-pairing в «Устройства» → «Сопряжение по PIN».
4. Логи: `<dataDir>/meshpad.log` или `.\scripts\collect-logs.ps1`

## Ручной чеклист MVP

### Лента и заметки

- [ ] Создать заметку с Markdown; `# заголовок` → title в meta.json
- [ ] Заметка только с файлом — без «_Пустая заметка_»
- [ ] Сортировка created / updated сохраняется после перезапуска
- [ ] Прокрутка вверх подгружает старые заметки

### Вложения

- [ ] Изображение → превью в ленте, lightbox
- [ ] Видео (Win): постер, tap → воспроизведение
- [ ] Аудио: inline player
- [ ] Большой файл — progress при копировании
- [ ] DnD файла в composer (Win/Linux)

### Sync (два устройства в LAN)

- [ ] Обнаружение в «Устройства»
- [ ] PIN-pairing (без «доверять» без PIN)
- [ ] Sync: заметка появляется на втором устройстве
- [ ] Удаление → корзина → sync → восстановление

### Прочее

- [ ] Android Share-to → новая заметка
- [ ] «Проверить данные» после ручного изменения FS
- [ ] Поиск по тексту и имени вложения
- [ ] Web: лента через server, paginated load

## CI

Pull request → GitHub Actions: analyze, format, test (`.github/workflows/ci.yml`).

## VS Code / Cursor

Расширения: `.vscode/extensions.json`.

## Post-MVP

Следующий этап — [PLAN.md §12](../PLAN.md#12-post-mvp--план-развития): auth token на LAN sync → libp2p → Web push.
