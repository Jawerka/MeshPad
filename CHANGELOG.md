# Changelog

## [Unreleased]

---

## [0.2.12] — 2026-07-11

### Added

- **Foreground sync isolate:** LAN batch sync runs in a background isolate on Flutter (Windows, Linux, Android) and hub — UI and HTTP handlers stay responsive
- **`runForegroundLanSync`:** shared helper in `meshpad_p2p` (endpoint resolution on main isolate, sync in `Isolate.run`, progress via `SendPort`)
- **Android Wi‑Fi allow-list:** location permission flow, manual SSID entry, invalid `<unknown ssid>` cleanup on load
- **`safe_file_write`:** atomic writes for device identity and TLS material

### Changed

- Devices sheet and tray sync use `SyncController.runSync()` (isolate path); single-peer sync via `excludePeerIds`
- Hub `HeadlessLanSync` delegates to `runForegroundLanSync`
- LAN broadcast/discovery hardening; pairing QR UI improvements

### Fixed

- Android: `ACCESS_FINE_LOCATION` on API 33+, `FLAG_INCLUDE_LOCATION_INFO` for SSID on Android 12+
- Main-thread deadlock reading Wi‑Fi SSID from `MethodChannel`
- Feed header and manual sync no longer freeze the UI during outbound sync

---

## [0.2.11] — 2026-07-11

### Added

- **LAN discovery:** seed transport from stored endpoints before sync; adaptive discovery wait (200/400/800 ms); peer ordering uses stored IP + subnet + recent `lastSeenAt`
- **Auth recovery:** persist `auth_failure` per trusted device; signing-key reset banner; re-pair CTA on device cards; sync blocked until all peers re-paired or user confirms
- **Sync UX:** partial sync hints with peer counts; unreachable hints on manual sync; conflict copies count in Settings; sync diagnostics log (copy to clipboard); feed header warning when re-pairing required
- **Hub:** `onError` handler on headless LAN sync transport events stream

### Changed

- Signing key reset marker clears only after all trusted peers are re-paired (or explicit dismiss)

---

## [0.2.10] — 2026-07-11

### Added

- **Android release signing:** единый release keystore для CI и локальных сборок (`scripts/setup-android-signing.ps1`); проверка SHA-256 подписи APK в GitHub Actions

### Changed

- **Docs:** раздел «Подпись Android» в `docs/DEVELOPMENT.md`

---

## [0.2.9] — 2026-07-11

### Fixed

- **Android in-app update:** после скачивания APK запускается системный установщик через FileProvider (раньше `OpenFile` молча не открывал install intent)
- Подсказка при отсутствии разрешения «Установка из неизвестных источников» (Android 8+)

---

## [0.2.8] — 2026-07-10

### Added

- **LAN sync auth:** детализированные тела 401 (`unauthorized:token`, `:signature`, `:clock_skew` и др.); l10n-сообщения для каждой причины
- **Signing key reset:** маркер `signing_key_reset.json` при потере private key; блокировка sync с понятным сообщением до пересопряжения
- **Status hints:** компактные theme-aware подсказки сверху экрана вместо SnackBar (sync, настройки, устройства, pairing и др.)
- **Devices UX:** подсветка «Требуется пересопряжение» на карточке устройства после 401/403

### Changed

- **Docs:** таблица auth failure bodies в `docs/SYNC_WIRE.md`
- Auto-sync показывает ошибки через status hints

### Fixed

- Тихая ротация Ed25519 signing key без предупреждения при потере secure storage

---

## [0.2.7] — 2026-07-06

### Added

- **In-app updates:** проверка GitHub Releases API (ручная кнопка в настройках); накопительные release notes из `body` релиза
- **Release CI:** тело релиза из CHANGELOG (`extract-changelog-section.sh`), без `version.json`
- **Dev:** `scripts/clean-local.ps1` — очистка локальных сборок, логов и `data/`

### Changed

- **Wave 2 refactor (no behavior change):** `note_repository` part files, `lan_peer_server` route handlers, UI extracts (`pin_pairing_dialog`, `feed_composer_section`, `settings_update_actions`)
- **Docs:** секция Clean Code в AGENTS.md; ROADMAP debt C11–C15; локальная очистка в DEVELOPMENT.md
- `.gitignore`: корневые `meshpad-*.apk/zip/exe`

---

## [0.2.6] — 2026-07-06

### Added

- **Multi-device LAN sync:** тихий skip offline-пиров; multi-hop cascade (`excludePeerIds`, `hopLimit`); параллельный sync (2 пира в normal profile); hub-first ordering
- **Feed UX:** Ctrl+Enter в composer; контекстное меню заметки (ПКМ/long-press); выделение текста в Markdown
- **Windows release:** `scripts/build-windows.ps1` — exe, zip и Inno Setup installer в CI и локально
- **Android release:** `meshpad-<version>.apk` копируется в корень репозитория при сборке

### Changed

- Синхронизация снова на main isolate (исправлен stale Drift index после isolate sync)
- Snackbar при sync только для actionable ошибок (auth, timeout), не для спящих устройств
- Документация cascade и multi-peer orchestration в `docs/SYNC_WIRE.md`, `docs/ARCHITECTURE.md`

### Fixed

- Синхронизация переставала обновлять ленту после переноса sync в worker isolate

---

## [0.2.5] — 2026-07-04

### Added

- **LAN hub** (`meshpad_server --hub`): headless peer с веб-страницей PIN/QR, журналом синхронизации и Ubuntu/systemd-скриптами — [docs/HUB.md](docs/HUB.md)
- **Щадящий режим сети** в настройках (реже mDNS/UDP, без cascade)
- **Сохранение медиа** из полноэкранного просмотра фото/видео и превью в ленте
- **Сохранение любых вложений** по тапу (Windows/Android)
- **Очистка обнаруженных LAN-устройств:** dedupe по IP, TTL, «Удалить все доверенные»
- **AGENTS.md:** правило деплоя hub на `192.168.88.48`

### Changed

- Hub web: PIN и QR показываются только по кнопке; кнопки действий выше журнала
- CI: полный `validate` только на release-тегах `v*`

### Removed

- Мёртвый UI переключателя libp2p в настройках

---

## [0.2.0] — Post-MVP (2026-05)

Расширение после MVP 0.1.0.

### Added

- **LAN sync auth token (Phase A.1):** shared secret in `devices/trusted/<peer_id>.json`; headers `X-MeshPad-Peer-Id` + `X-MeshPad-Auth-Token` on all `/meshpad/p2p/*` except pairing and health; 401 without/wrong token, 403 for untrusted peer
- Auth token generated at PIN pairing and exchanged via `PinPairingConfirm`
- **Pairing hardening (Phase A.3):** centralized PIN offer TTL (`pairingOfferTtl`); rate limit on `/pairing/confirm` (429 after repeated failures)
- **Sync reliability (Phase C.1):** outbox retry count no longer bumped on transport-level sync failures
- **Partial sync ack (Phase C.2):** outbox clears only after remote has note meta and all attachment bytes verified
- **Resumable attachment upload (Phase C.3):** chunked LAN PUT with offset headers, GET upload status, sha256 finalize
- **Android background LAN sync (Phase C.4):** WorkManager pass runs purge, reconcile, and LAN sync with trusted peers
- **libp2p transport scaffold (Phase B.1/B.3):** `Libp2pSyncTransport` with LAN fallback, `createSyncTransport` factory, `SyncTransportKind` in settings; native API contract in [docs/LIBP2P.md](docs/LIBP2P.md)
- **Web feed push (Phase D.1):** SSE `GET /api/events` on `meshpad_server`; Web client auto-reloads feed via `WebFeedEventsListener`
- **Server-side image thumbs (Phase D.2):** on-demand JPEG previews at `GET /api/notes/<id>/attachments/<name>/thumb`; Web grid uses thumb URL in feed
- **API key auth (Phase D.3):** optional `X-MeshPad-Api-Key` on `/api/*` (except health); server `--api-key` / `MESHPAD_API_KEY`; Web client stores key in settings
- **libp2p sidecar bridge (Phase B.2):** HTTP sidecar on `:45839`, `HttpLibp2pNativeApi`, `Libp2pSyncTransport` auto-connect
- **macOS client (Phase D.4):** `macos/` Flutter target, tray + LAN discovery, Bonjour entitlements
- **LAN TLS sync (Phase B.4):** HTTPS on port 45840, self-signed cert in `devices/tls/`, SHA-256 pinning at PIN pairing
- **Partial push outbox retry (C.1 follow-up):** per-note retry bump when attachment/meta push fails mid-batch; transport failures still skip global bump
- **Rust libp2p sidecar stub (B.2):** `native/meshpad_p2p_native/` axum HTTP sidecar matching `:45839` API
- **Sidecar mDNS discovery (B.2):** Dart sidecar browse-only mDNS → SSE `peer_discovered` with LAN endpoint; `Libp2pSyncTransport` caches endpoints
- **Notes export/import (Phase E.1):** `NotesArchive` zip of `notes/`; settings UI; LWW merge on import; `devices/` excluded
- **Sync transport setting:** LAN vs libp2p in app settings (restarts transport provider)
- **Light theme (Phase E.2):** dark / light / system; `MeshPadPalette`, `theme_mode` in settings
- **Note tags (Phase E.3):** tags in `meta.json`, Drift index, feed filter chips, tag editor on notes
- **libp2p B.2 prep:** merged LAN+sidecar events, native `requestSync` ping + LAN fallback; [docs/SYNC_WIRE.md](docs/SYNC_WIRE.md); Rust sidecar `cargo check` in CI
- **i18n (Phase E.4):** ru/en + system locale; `AppLocalizations` via `flutter gen-l10n`; language setting in app settings; localized settings sheet, tags UI, note menu

### Notes

- App version **0.2.0**; post-MVP phases A–E delivered; libp2p archived in 1.0 (ADR 0003)
- CI: `melos run check` (analyze + unit + flutter tests)

---

## [0.1.0] — MVP (2026-05)

Первый рабочий релиз.

### Суть MVP

Local-first Markdown-лента, вложения с превью (images/video/audio), корзина 7 дней, FTS, LAN sync (mDNS/HTTP) с PIN-pairing, Android share-to, desktop tray, Web через headless API.

### Added

- Monorepo: `meshpad_core`, `meshpad_p2p`, `meshpad_api_client`, `meshpad`, `meshpad_server`
- FS + Drift, LWW sync, outbox, device identity, LAN transport
- UI: header-only navigation, lazy feed, inline edit, devices sheet, settings
- Media: `.thumbs/` cache, video poster (Win/Linux), inline audio/video (mobile)
- Web: paginated API, RemoteNotesService, attachment upload
- Auto-sync: debounced on edit + periodic timer; purge trash on sync tick
- `video_player_win`, Windows `nuget.config`

### Changed (UX / design decisions)

- **No sidebar** — header navigation only (ref sidebar not implemented)
- **No sync icons on note cards** — sync status in header only
- **Trash in header** — not FAB
- **No «MeshPad» title** in feed header
- **Sync icon** rotates counter-clockwise (not spinner)
- **PIN-only trust** — removed «Доверять» without PIN
- **Empty note placeholder** hidden when attachments present
- Settings text: LAN sync active (not «libp2p next sprint»)

### Fixed

- Windows NuGet build for audioplayers
- Mobile devices sheet overflow; compact device cards

### Documentation

- PLAN, ARCHITECTURE, DEVELOPMENT aligned with implemented MVP

---

<details>
<summary>Detailed development history</summary>

### Sprint highlights

- **S0–S3:** infra, data layer, feed, attachments, FTS, trash TTL
- **S4:** SyncEngine, LAN HTTP/UDP, mDNS, PIN pairing, header sync indicator
- **S5:** tray, share-to, WorkManager, headless server, Web client
- **S6:** pagination, errors, update check, media preview, MVP completion

### Incremental features (pre-0.1.0 commits)

- Device icon picker, LAN endpoint in devices sheet
- FTS title + attachment names, auto-title from Markdown
- Feed sort toggle (native + Web persistence)
- Auto-sync on local mutations (400 ms debounce)
- Revoke trust + forgetPeer, purge exhausted outbox
- Firewall script for dynamic TCP ports

</details>
