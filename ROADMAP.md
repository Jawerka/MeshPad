# MeshPad Roadmap

Development plan for MeshPad 1.0+. **North star:** reliable LAN-first sync pipeline (write → outbox → sync → peer). A failure on one peer or attachment must not stop the rest. Secondary: Git sync, UI polish, platform packaging.

Source of truth: code and [CHANGELOG.md](CHANGELOG.md). Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Wave 0 — Pipeline Correctness (current)

**Goal:** Main path works under partial failures; no silent stuck state.

- [x] Per-peer continue-on-error in `LanSyncCoordinator`
- [x] Extract `syncSingleTrustedPeer` helper
- [x] Per-attachment try/catch in `remote_sync_gateway.dart`
- [x] Attachment push failure → `failedPushNoteIds` → outbox retry bump
- [x] PIN pairing host/guest UX + dual log collection (commit `e5127be`)
- [x] `confirmPairing` HTTP failures logged (status + body snippet)
- [x] `onError` on transport event streams (single-peer sync, pairing dialog, connectivity)
- [x] Feed UI feedback for partial/failed manual sync
- [x] No auto-purge of exhausted outbox on startup (use Settings → purge)
- [x] `SyncTransportException` does not bump entire outbox in coordinator catch
- [x] Pipeline E2E + coordinator partial-failure tests
- [ ] Manual LAN smoke-test Win ↔ Android after each release candidate

### Manual smoke checklist

1. Same Wi‑Fi, no AP client isolation
2. Windows firewall: `.\scripts\allow-meshpad-firewall.ps1` (admin, once)
3. **Host** opens PIN/QR; **guest** enters PIN or scans QR
4. Create note on A → auto sync → visible on B
5. Delete → trash → sync → restore
6. Logs: `.\dev.ps1 -Device dual -CollectLogs` → `logs/latest-dual.log`

---

## Wave 1 — Observability & Sync UX

- Structured sync metrics per peer in `meshpad.log` (extend existing `sync_duration_ms`, `sync_bytes`)
- Adaptive discovery backoff (replace fixed 600 ms wait in endpoint resolver)
- Progress-aware timeout for large attachment batches
- Snackbar detail: failed peer count on `SyncRunStatus.partial`
- mDNS `Bad state: Cannot add event after closing` — investigate upstream `mdns_dart`

---

## Wave 2 — Clean Code Refactor (no behavior change)

**Goal:** SRP splits and DRY without wire-format changes.

| File | ~lines | Action |
|------|--------|--------|
| `note_repository.dart` | 883 | `part`: CRUD, outbox, reconcile, attachments |
| `lan_sync_transport.dart` | ~780 | Extract `LanEndpointResolver` |
| `lan_peer_server.dart` | 516 | Route table + handlers |
| `http_remote_sync_gateway.dart` | ~490 | Shared `_request` wrapper |
| `devices_sheet.dart` | 1384 | `pin_pairing_dialog.dart`, `device_card.dart` |
| `settings_sheet.dart` | 1332 | Section widgets |
| `feed_screen.dart` | 831 | Composer widget (partial: `sync_run_feedback.dart` done) |

DRY backlog:

- [x] `trustDeviceFromPairingConfirm` / `trustDeviceFromPairingOffer`
- [ ] `createLanSyncStack()` factory (coordinator + transport wiring)
- [ ] `LanSyncRunStatus` ↔ `SyncRunStatus` single mapper
- [ ] L10n for hardcoded RU in coordinator messages

---

## Wave 3 — Data Integrity

- Background reconcile on startup (non-blocking)
- Incremental reconcile (avoid full catalog scan every run)
- Outbox maintenance UI: failed entries, retry, purge (Settings section exists — expand visibility)
- Reconcile edge-case tests (delete/trash/restore across peers)

---

## Wave 4 — Platform Polish

- Android background sync (WorkManager, battery whitelist docs)
- Desktop tray improvements
- Linux packaging (.deb / AppImage)

---

## Wave 5 — Git Channel

- Conflict resolution UX for Git mirror
- Selective note export to Git
- Attachment policy docs (Git never syncs attachments)

---

## Out of scope

- libp2p as production transport ([ADR 0003](docs/ADR/0003-simplicity-lan-git.md))
- Web browser product, iOS / macOS clients
- Enterprise / commercial security (SSO, audit logs, compliance)

---

## Technical debt register

| ID | Issue | Status |
|----|-------|--------|
| C1 | Attachment fail left outbox at retryCount=0 | **Fixed** — `failedPushNoteIds` after attachment check |
| C2 | Pairing trust asymmetric if initiator endpoint null | Mitigated — guest sends full initiator fields; host uses `trustDeviceFromPairingConfirm` |
| C3 | Batch `recordSyncFailure` on unexpected errors | **Fixed** — skip for `SyncTransportException` |
| C4 | Feed ignored sync result | **Fixed** — `showSyncRunFeedback` |
| C5 | 401/403 → forgetPeer | By design — re-pair required |
| C6 | `confirmPairing` silent false | **Fixed** — logged |
| C7 | Stream listeners without `onError` | **Partial** — key paths covered |
| C8 | Startup purge hid failed sync | **Fixed** — purge only via Settings |
