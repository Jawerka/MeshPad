# MeshPad Roadmap

Development plan for MeshPad 1.0+. Priority: **reliable LAN sync pipeline** (write → outbox → sync → peer). Secondary: Git sync, UI polish.

Source of truth for behavior: code and [CHANGELOG.md](CHANGELOG.md). Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Wave 1 — Pipeline Resilience (current)

**Goal:** Main sync path survives non-critical errors; one bad peer must not block others.

- [x] Per-peer continue-on-error in `LanSyncCoordinator`
- [x] Extract `syncSingleTrustedPeer` helper
- [x] Per-attachment try/catch in `remote_sync_gateway.dart`
- [x] Error boundaries in `SyncController`, sync loop, discovery listeners
- [x] Safe JSON parsing on LAN wire (400 instead of opaque 500)
- [x] Pipeline E2E tests (`pipeline_e2e_test.dart`, coordinator partial failure)
- [x] CI runs `melos run flutter:test`
- [x] Release APK build + `install-android-apk.ps1`
- [ ] Manual LAN smoke-test Win ↔ Android after each release candidate

---

## Wave 2 — Clean Code Refactor

**Goal:** Maintainable pipeline code without behavior changes.

- [ ] Split `note_repository.dart` into CRUD / outbox / reconcile / attachments (`part` files)
- [ ] Split `lan_sync_transport.dart` → endpoint resolver + sync session
- [ ] Split `lan_peer_server.dart` → routes + attachment handlers
- [ ] HTTP gateway: shared `_request` wrapper in `http_sync_client.dart`
- [x] Shared helpers: `parseLanAttachmentPath`, `hasLanTransport`, `trustDeviceFromPairingConfirm`
- [ ] Split UI sheets: `settings_sheet`, `devices_sheet`, feed composer widget

---

## Wave 3 — Sync Quality

- Adaptive discovery backoff (replace fixed 600 ms wait)
- Progress-aware timeout for large attachment sets
- Structured sync metrics in `meshpad.log`
- Partial sync UI feedback (`SyncRunStatus.partial`)

---

## Wave 4 — Data Integrity

- Background reconcile on startup (non-blocking)
- Incremental reconcile optimization
- Outbox maintenance UI (failed entries, retry, purge)

---

## Wave 5 — Platform Polish

- Android background sync hardening (WorkManager, battery whitelist docs)
- Desktop tray improvements
- Linux packaging (.deb / AppImage)

---

## Wave 6 — Git Channel

- Conflict resolution UX for Git mirror
- Selective note export to Git
- Attachment policy documentation (Git never syncs attachments)

---

## Out of scope

- libp2p as production transport ([ADR 0003](docs/ADR/0003-simplicity-lan-git.md))
- Web browser product
- iOS / macOS clients
- Enterprise security (SSO, audit logs, compliance hardening)

---

## Verification checklist (LAN)

1. Both devices on same Wi‑Fi (no AP client isolation)
2. PIN pairing via **Devices**
3. Create note on A → auto sync → visible on B
4. Delete → trash → sync → restore
5. Logs: `.\scripts\collect-logs.ps1 -Source both`
