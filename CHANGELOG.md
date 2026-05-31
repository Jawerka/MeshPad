# Changelog

## [Unreleased]

### Fixed

- Windows: сборка падала на `audioplayers_windows` (NuGet `primarySources` пустой) — добавлен `windows/nuget.config`.

### Added

- Feed sort toggle: по дате создания / по дате изменения (сохраняется в `app_settings.json`); доступен и в Web-клиенте.
- Trash cards show auto-purge date (7 дней).
- LAN sync: clear stale trusted endpoint on unreachable peer; firewall script for dynamic TCP ports.
- Выбор иконки устройства (локальное и доверенные) — предустановленный набор, цвет по `peer_id`.
- Поиск по заголовку заметки (FTS и fallback LIKE).
- Поиск по именам вложений (FTS + LIKE).
- Авто-заголовок из Markdown (`# heading` или первая строка) при создании/редактировании.
- Превью видео и аудио во вложениях (inline-плеер в ленте; изображения — как раньше).
- В листе «Устройства» показывается LAN-эндпоинт (локальный порт и адрес доверенных).
- HTTP API: `GET /api/notes?sort=updated_at`.
- Отзыв доверия сбрасывает кэш peer в LAN transport; очистка исчерпанных записей outbox в настройках.

### Removed

- Desktop sidebar (`ConvSidebar`) — навигация только через шапку (см. PLAN §4.1).
- Иконки sync на карточках заметок — статус sync только в шапке (см. PLAN §4.3).

### Changed

- Expanded `PLAN.md` with architecture, testing, sprints, risks.
- Monorepo: `packages/meshpad_core`, `packages/meshpad_p2p`, `apps/meshpad`.
- Dev tooling: Melos, CI, setup scripts, EditorConfig, VS Code settings.
- Core: `NoteMeta`, file repository, LWW merge, unit tests.
- Git repository, Android AVD `MeshPad_API36`, `scripts/launch-emulator.ps1`.
- **Sprint 1:** Drift DB, `NoteRepository` (FS + index), models Device/SyncEvent.
- **Sprint 2:** Chat UI — sidebar, feed, composer, inline edit, trash, Markdown preview.
- **Sprint 3:** Attachments, image preview/lightbox, FTS search, sync outbox indicator, trash TTL purge.
- **Sprint 4 (partial):** Device identity, SyncEngine, FakeSyncHub, LAN HTTP/UDP sync transport with PIN pairing over LAN.
- **Sprint 5 (partial):** Windows/Linux system tray, settings sheet, customizable data directory, auto-sync loop, rebuild index, Android Share-to, WorkManager background maintenance, headless HTTP server (`apps/meshpad_server`), Web client via `meshpad_api_client`.
- **Sprint 6 (partial):** Manual update check in settings, LAN discovery stub UI, lazy paginated feed, MeshPadException and sync error messages, PIN pairing protocol models, update download link, attachment copy progress UI.
- **Sprint 4 (continued):** mDNS discovery (`_meshpad._tcp`) + UDP fallback; LAN sync with attachments; headless server LAN P2P (`--p2p`).
- **Sprint 5 (continued):** Web-клиент — загрузка вложений через `PUT /api/notes/<id>/attachments/<name>`.
