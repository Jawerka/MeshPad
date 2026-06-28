# Changelog

## [Unreleased]

### Added

- **MeshPad 1.0 (ADR 0003):** production sync = LAN only; Git sync (desktop); payload encryption; network-aware discovery
- **GitHub OAuth:** Device Flow для Git sync — [docs/GIT_SYNC.md](docs/GIT_SYNC.md)
- **UI:** заголовок заметки по дате/времени; «Скопировать всё» (desktop)

### Changed

- Документация актуализирована под 1.0; libp2p помечен archived
- `sync_transport: libp2p` мигрирует в `lan` при загрузке настроек
- Бенчмарк reconcile 1000 notes — opt-in (`dart test --tags benchmark`)

### Removed

- **CI/release:** Rust libp2p FFI jobs и native FFI в release pipelines
- HTML-референс `ref/` (устаревший прототип UI)

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
