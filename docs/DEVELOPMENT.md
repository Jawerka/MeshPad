# Разработка MeshPad

Релиз **0.2.0** (MVP 0.1.0 + post-MVP). Поведение — [PLAN.md §5](../PLAN.md#5-реализованное-mvp-010) и [CHANGELOG.md](../CHANGELOG.md). Архитектура — [ARCHITECTURE.md](ARCHITECTURE.md).

**Production sync:** LAN only. libp2p toggle скрыт в настройках до B.2 — [LIBP2P.md](LIBP2P.md).

## Требования

| Инструмент | Версия / примечание |
|------------|---------------------|
| Git | 2.x |
| Flutter | stable (см. `.fvmrc`) |
| Dart | идёт с Flutter |
| Android Studio / SDK | для Android |
| Visual Studio 2022 | C++ workload — для `windows` |
| clang/cmake | для `linux` desktop |
| Xcode | для `macos` desktop (сборка только на macOS) |
| Rust toolchain | опционально; `cargo check` для `native/meshpad_p2p_native/` (CI) |

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
| macOS | `cd apps/meshpad && flutter run -d macos` (на Mac) |
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
| GET | `/api/health` | Проверка (`auth`: none / api_key) |
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
| GET | `/api/events` | SSE push обновлений ленты |
| GET | `/api/notes/<id>/attachments/<name>/thumb` | JPEG превью (Web grid) |
| GET | `/api/notes/<id>/attachments/<name>` | Файл |

Опциональный API key: `--api-key` / env `MESHPAD_API_KEY`; Web хранит ключ в настройках.

## Поведение приложения (0.2.0)

### UI

- Навигация **только через шапку** (sidebar из `ref/` не используется).
- Sync и корзина — в шапке; sync-иконка вращается при активной синхронизации.
- На карточках заметок **нет** иконок sync.
- **Тема:** тёмная (по умолчанию), светлая или системная — в настройках (`theme_mode`).
- **Язык:** ru / en / системный — в настройках (`locale_mode`).
- **Теги:** в `meta.json`, меню заметки → «Теги»; фильтр по тегу в ленте (не Web).

### Sync (LAN)

| Порт | Назначение |
|------|------------|
| 45837 | UDP discovery |
| 45838 | HTTP pairing + sync fallback |
| 45839 | libp2p sidecar (dev/backlog) |
| 45840 | HTTPS sync (pinned cert после PIN) |

- Discovery: mDNS `_meshpad._tcp` + UDP; повторный browse при открытии «Устройства» и при resume приложения.
- Pairing: **только PIN**; auth token в `trusted/<peer_id>.json`.
- Sync data: HTTPS `:45840` с cert pinning; fallback HTTP `:45838`.
- Auto-sync: debounce ~400 ms после правок + таймер 15–60 мин (настройки).
- Android WorkManager: reconcile + purge + **LAN sync** (мин. 15 мин, требуется сеть).

### libp2p (не production)

- Код: `Libp2pSyncTransport`, sidecar `native/meshpad_p2p_sidecar`, Rust stub `native/meshpad_p2p_native`.
- Переключатель в настройках **скрыт** (`MeshPadFeatureFlags.libp2pTransportSettingVisible = false`).
- Сохранённый `"sync_transport": "libp2p"` в `app_settings.json` → runtime **LAN**.
- Dev-only: `--dart-define=MESHPAD_SYNC_TRANSPORT=libp2p`.
- Wire format: [SYNC_WIRE.md](SYNC_WIRE.md). Планы: [LIBP2P.md](LIBP2P.md), [PLAN.md §13](../PLAN.md#13-бэклог-вне-текущего-релиза).

### Данные

- FS — источник истины; «Проверить данные» → reconcile + rebuild `.thumbs/`.
- **Экспорт/импорт:** настройки → zip `notes/` (без `devices/`); импорт по LWW.
- Корзина: 7 дней, purge при sync tick и maintenance.
- Логи: `<dataDir>/meshpad.log` или `.\scripts\collect-logs.ps1`.

### Платформы

| Платформа | Особенности |
|-----------|-------------|
| Windows | Tray; `nuget.config`; видео-постер; firewall script |
| Linux | Tray; DnD в composer |
| macOS | Tray; LAN discovery (Bonjour); sandbox + local network prompt |
| Android | Share-to; WorkManager; compact devices UI |
| Web | Thin client; SSE; server thumbs; sort в SharedPreferences |

Окно Windows: `%LOCALAPPDATA%\MeshPad\window_state.ini`.

## Тестовый прогон

```powershell
dart run melos run check
# или
.\scripts\test-run.ps1
```

## Monorepo

| Путь | Назначение |
|------|------------|
| `apps/meshpad` | Flutter UI |
| `apps/meshpad_server` | REST + `--p2p` |
| `packages/meshpad_core` | домен, FS, Drift, sync, thumbnails, export |
| `packages/meshpad_p2p` | LAN transport, libp2p scaffold |
| `packages/meshpad_api_client` | HTTP для Web |
| `native/meshpad_p2p_sidecar` | Dart libp2p sidecar HTTP |
| `native/meshpad_p2p_native` | Rust sidecar stub |

## Codegen (Drift)

```powershell
cd packages/meshpad_core
dart run build_runner build --delete-conflicting-outputs
```

## Локализация (i18n)

- ARB: `apps/meshpad/lib/l10n/app_ru.arb`, `app_en.arb`
- Генерация: `cd apps/meshpad && flutter gen-l10n`
- Настройка: **Настройки → Язык** (`locale_mode`: `ru` / `en` / `system`)
- Импорт: `import 'package:meshpad/l10n/app_localizations.dart';` → `AppLocalizations.of(context)`

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

1. Оба устройства в **одной Wi‑Fi** (без «изоляции клиентов» на роутере).
2. **Устройства** — откройте лист: запускается повторный mDNS/UDP browse; в «Обнаруженные» должны появиться соседи (до PIN).
3. Firewall (Windows): `.\scripts\allow-meshpad-firewall.ps1`
4. PIN-pairing: «Сопряжение по PIN» у обнаруженного устройства.
5. Логи: `<dataDir>/meshpad.log` — ищите `discovery`, `mDNS`, `UDP`, `LAN`; сбор: `.\scripts\collect-logs.ps1`

### libp2p / sidecar (dev)

```powershell
dart run meshpad_p2p_sidecar
# или Rust stub:
cargo run -p meshpad_p2p_native
```

Sidecar слушает `http://127.0.0.1:45839`. Push/pull в Rust — бэклог B.2.

## Ручной чеклист

### Лента и заметки

- [ ] Создать заметку с Markdown; `# заголовок` → title в meta.json
- [ ] Заметка только с файлом — без «_Пустая заметка_»
- [ ] Сортировка created / updated сохраняется после перезапуска
- [ ] Прокрутка вверх подгружает старые заметки
- [ ] Теги: добавить, фильтр в ленте

### Вложения

- [ ] Изображение → превью в ленте, lightbox
- [ ] Видео (Win): постер, tap → воспроизведение
- [ ] Аудио: inline player
- [ ] Большой файл — progress при копировании
- [ ] DnD файла в composer (Win/Linux)

### Sync (два устройства в LAN)

- [ ] Обнаружение в «Устройства» (после открытия листа)
- [ ] PIN-pairing (без «доверять» без PIN)
- [ ] Sync: заметка появляется на втором устройстве
- [ ] Удаление → корзина → sync → восстановление

### Прочее

- [ ] Android Share-to → новая заметка
- [ ] «Проверить данные» после ручного изменения FS
- [ ] Поиск по тексту и имени вложения
- [ ] Экспорт/импорт zip в настройках
- [ ] Светлая тема / смена языка ru↔en
- [ ] Web: лента через server, paginated load
- [ ] Web: SSE — новая заметка без ручного refresh
- [ ] Web: превью через `/thumb`, lightbox — полный файл

## CI

Pull request → GitHub Actions: analyze, format, test, `cargo check` (`.github/workflows/ci.yml`).

## VS Code / Cursor

Расширения: `.vscode/extensions.json`.

## Бэклог

Дорожная карта §12 **закрыта**. Следующие задачи — [PLAN.md §13](../PLAN.md#13-бэклог-вне-текущего-релиза): libp2p push/pull (B.2), история версий (E.5), in-app updates (E.6).
