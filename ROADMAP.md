# MeshPad Roadmap

Development plan for MeshPad 1.0+. **North star:** reliable LAN-first sync pipeline (write → outbox → sync → peer). A failure on one peer or attachment must not stop the rest. Secondary: Git sync, hub ops, UI polish, platform packaging.

Source of truth: code and [CHANGELOG.md](CHANGELOG.md). Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Project audit (2026-07)

### Strengths

| Area | Assessment |
|------|------------|
| **Sync pipeline** | Clear layering: FS truth → Drift index → outbox → `LanSyncCoordinator` → per-peer continue-on-error |
| **Resilience** | Partial sync, attachment retry, `SyncTransportException` vs outbox bump, 401/403 → re-pair |
| **Testing** | Strong package tests (`lan_sync_test`, `pipeline_e2e_test`, coordinator partial-failure) |
| **Hub** | Headless peer + web PIN/QR; same sync stack as clients |
| **Docs** | ARCHITECTURE, SYNC_WIRE, HUB, AGENTS — agents and humans can navigate |

### Gaps (prioritized)

| Priority | Gap | Risk | Target wave |
|----------|-----|------|-------------|
| **P0** | Manual Win ↔ Android smoke not in CI | Regressions slip to release | Wave 0 |
| **P0** | `note_repository.dart` monolith (~900 lines) | Hard to change pipeline safely | Wave 2 |
| **P1** | No automated hub deploy in CI (artifact only) | Drift between hub and app releases | Wave 1 |
| **P1** | Discovery fixed 600 ms wait | Slow sync on flaky Wi‑Fi | Wave 1 |
| **P1** | Flutter UI tests thin vs core/p2p | Feed/composer regressions | Wave 1 |
| **P2** | Hardcoded RU strings in coordinator/server | i18n inconsistency | Wave 2 |
| **P2** | Git sync manual, no conflict UX | Secondary channel friction | Wave 5 |
| **P3** | libp2p native code archived but present | Repo noise | Out of scope / ADR |

### Reliability principles (non‑negotiable)

1. **Filesystem is source of truth** — Drift is rebuildable index.
2. **Outbox ack only when meta + attachments match** on remote (`sync_ack.dart`).
3. **One peer failure ≠ batch failure** — coordinator continues, returns `partial`.
4. **Transport down ≠ data corrupt** — do not bump outbox on `SyncTransportException`.
5. **Streams must have `onError`** — log via `MeshPadLog.warn`, never silent hang.
6. **Hub is a peer** — same wire format; hub web is ops UI only.

### Test matrix (main pipeline)

| Layer | File / command | Covers |
|-------|----------------|--------|
| Core | `note_repository_test.dart` | CRUD, trash, outbox, reconcile |
| Core | `device_identity_store_test.dart` | trust, revoke, remote name sync |
| Core | `sync_engine` / gateway tests | push/pull, ack, attachments |
| P2P | `lan_sync_test.dart` | two-peer LAN harness |
| P2P | `pipeline_e2e_test.dart` | full write → sync → read |
| P2P | `lan_sync_coordinator_test.dart` | partial failure, no outbox bump |
| Server | `hub_web_test.dart` | hub UI, revoke, status API |
| App | `melos run flutter:test` | widgets, note bubble, feed pieces |

Run before every pipeline change: `.\dev.ps1 -Test -WithFormat`

---

## Wave 0 — Pipeline Correctness (current)

**Goal:** Main path works under partial failures; no silent stuck state.

- [x] Per-peer continue-on-error in `LanSyncCoordinator`
- [x] Extract `syncSingleTrustedPeer` helper
- [x] Per-attachment try/catch in `remote_sync_gateway.dart`
- [x] Attachment push failure → `failedPushNoteIds` → outbox retry bump
- [x] PIN pairing host/guest UX + dual log collection
- [x] `confirmPairing` HTTP failures logged (status + body snippet)
- [x] `onError` on transport event streams (key paths)
- [x] Feed UI feedback for partial/failed manual sync
- [x] No auto-purge of exhausted outbox on startup
- [x] `SyncTransportException` does not bump entire outbox
- [x] Pipeline E2E + coordinator partial-failure tests
- [x] Hub: revoke trusted devices, empty trash API + UI
- [x] Trusted device names follow remote unless locally customized
- [x] CI builds `meshpad-hub-*-linux-x64` AOT on release
- [ ] Manual LAN smoke-test Win ↔ Android after each release candidate

### Manual smoke checklist

1. Same Wi‑Fi, no AP client isolation
2. Windows firewall: `.\scripts\allow-meshpad-firewall.ps1` (admin, once)
3. **Host** opens PIN/QR; **guest** enters PIN or scans QR
4. Create note on A → auto sync → visible on B
5. Delete → trash → sync → restore
6. Hub (optional): pair both devices to `http://192.168.88.48:8787/`, verify store-and-forward
7. Logs: `.\dev.ps1 -Device dual -CollectLogs` → `logs/latest-dual.log`

---

## Wave 1 — Observability, Hub ops & Sync UX

- [x] Hub deploy script (`scripts/deploy-hub.ps1`)
- [ ] Structured sync metrics per peer in `meshpad.log` (extend `sync_duration_ms`, `sync_bytes`)
- [ ] Adaptive discovery backoff (replace fixed 600 ms wait in endpoint resolver)
- [ ] Progress-aware timeout for large attachment batches
- [ ] Snackbar detail: failed peer count on `SyncRunStatus.partial`
- [ ] Flutter integration test: create note → mock sync complete → feed shows note
- [ ] mDNS `Bad state: Cannot add event after closing` — investigate upstream `mdns_dart`
- [ ] Optional: post-release job to push hub binary to known host (SSH secret)

---

## Wave 2 — Clean Code Refactor (no behavior change)

**Goal:** SRP splits and DRY without wire-format changes.

| File | ~lines | Action |
|------|--------|--------|
| [x] `note_repository.dart` | 107 (+ parts) | `part`: CRUD, outbox, reconcile, attachments |
| `lan_sync_transport.dart` | ~780 | Extract `LanEndpointResolver` |
| [x] `lan_peer_server.dart` | 445 (+ routes part) | Route table + handlers |
| `http_remote_sync_gateway.dart` | ~490 | Shared `_request` wrapper |
| [x] `devices_sheet.dart` | 743 | `pin_pairing_dialog.dart`, `device_card.dart`, `device_actions.dart` |
| [x] `settings_sheet.dart` | 1243 | `settings_update_actions.dart` |
| [x] `feed_screen.dart` | 712 | `feed_composer_section.dart` |

DRY backlog:

- [x] `trustDeviceFromPairingConfirm` / `trustDeviceFromPairingOffer`
- [ ] `createLanSyncStack()` factory (coordinator + transport wiring)
- [ ] `LanSyncRunStatus` ↔ `SyncRunStatus` single mapper
- [ ] L10n for hardcoded RU in coordinator messages

---

## Wave 3 — Data Integrity

- [x] Incremental reconcile (mtime signatures)
- [ ] Background reconcile on startup (non-blocking)
- [ ] Outbox maintenance UI: failed entries, retry, purge (expand Settings visibility)
- [ ] Reconcile edge-case tests (delete/trash/restore across peers)
- [ ] Property test: outbox never acks before attachment verify

---

## Wave 4 — Platform Polish

- [ ] Android background sync (WorkManager, battery whitelist docs)
- [ ] Desktop tray improvements
- [ ] Linux packaging (.deb / AppImage)
- [x] In-app update checks for Windows + Android (GitHub Releases API, release notes in body)

---

## Wave 5 — Git Channel

- [ ] Conflict resolution UX for Git mirror
- [ ] Selective note export to Git
- [ ] Attachment policy docs (Git never syncs attachments)

---

## Out of scope

- libp2p as production transport ([ADR 0003](docs/ADR/0003-simplicity-lan-git.md))
- Web browser product, iOS / macOS clients
- Enterprise / commercial security (SSO, audit logs, compliance) — see [docs/SECURITY.md](docs/SECURITY.md) for threat model only

---

## Technical debt register

| ID | Issue | Status |
|----|-------|--------|
| C1 | Attachment fail left outbox at retryCount=0 | **Fixed** — `failedPushNoteIds` |
| C2 | Pairing trust asymmetric if initiator endpoint null | Mitigated — guest sends full initiator fields |
| C3 | Batch `recordSyncFailure` on unexpected errors | **Fixed** — skip for `SyncTransportException` |
| C4 | Feed ignored sync result | **Fixed** — `showSyncRunFeedback` |
| C5 | 401/403 → forgetPeer | By design — re-pair required |
| C6 | `confirmPairing` silent false | **Fixed** — logged |
| C7 | Stream listeners without `onError` | **Partial** — key paths covered |
| C8 | Startup purge hid failed sync | **Fixed** — purge only via Settings |
| C9 | Stale trusted device names | **Fixed** — `syncRemoteDisplayNameIfAllowed` + `name_customized` |
| C10 | Hub not in release CI | **Fixed** — `build-hub-linux` job |
| C11 | `lan_peer_server._route` monolith (~180+ lines) | **Fixed** — `lan_peer_server_routes.dart` |
| C12 | `note_repository.dart` monolith (~971 lines, no `part`) | **Fixed** — part files |
| C13 | Flutter UI sheets >1300 lines | **Fixed** — extracted widgets (devices/settings/feed) |
| C14 | In-app updates via broken `version.json` | **Fixed** — GitHub Releases API |
| C15 | Release body auto-generated on old tags | **Fixed** in CI; optional manual backfill for 0.2.5–0.2.6 |
