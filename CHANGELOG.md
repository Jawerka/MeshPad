# Changelog

## [Unreleased]

### Added

- **LAN sync auth token (Phase A.1):** shared secret in `devices/trusted/<peer_id>.json`; headers `X-MeshPad-Peer-Id` + `X-MeshPad-Auth-Token` on all `/meshpad/p2p/*` except pairing and health; 401 without/wrong token, 403 for untrusted peer
- Auth token generated at PIN pairing and exchanged via `PinPairingConfirm`
- **Pairing hardening (Phase A.3):** centralized PIN offer TTL (`pairingOfferTtl`); rate limit on `/pairing/confirm` (429 after repeated failures)
- **Sync reliability (Phase C.1):** outbox retry count no longer bumped on transport-level sync failures

### Post-MVP (planned)

- Native libp2p transport (Phase B)
- Per-note outbox bump on partial push failure (C.1 follow-up)

---

## [0.1.0] — MVP (2026-05)

Первый рабочий релиз. См. [PLAN.md §5](PLAN.md#5-реализованное-mvp-010) — источник истины по поведению.

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
- Post-MVP roadmap (Phases A–E) in PLAN §12

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
