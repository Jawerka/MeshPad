# AGENTS.md — Working with MeshPad

Guide for AI coding agents (Cursor, etc.) in this repository.

## Project summary

MeshPad is a **local-first Markdown notebook** with a chat-style feed UI. Production sync is **LAN-only** (mDNS/UDP + HTTP/HTTPS, PIN pairing, encrypted payloads). **Git sync** is secondary (desktop, manual, no attachments).

Stack: **Dart 3 + Flutter + melos** (not Python). Quality tools: `dart analyze`, `dart format`, `flutter_lints` — **not** PEP8/mypy/pytest.

Supported: **Windows**, **Android**, Linux (CI compile). Not supported: iOS, macOS, Web product.

## Monorepo layout

| Path | Role |
|------|------|
| `packages/meshpad_core` | Pure Dart: FS, Drift DB, sync engine, outbox, Git — **no Flutter** |
| `packages/meshpad_p2p` | LAN transport, discovery, pairing, coordinator |
| `apps/meshpad` | Flutter UI (Riverpod) |
| `apps/meshpad_server` | Headless hub (`--hub`) + REST/SSE (dev) |
| `packages/meshpad_api_client` | HTTP client for Web dev stubs |
| `native/meshpad_p2p_*` | Archived libp2p experiments — **not production** |

## Main pipeline (do not break)

```
FeedScreen → NoteRepository → FS + Drift + sync_outbox
  → SyncScheduler (400 ms) → SyncController.runSync
  → LanSyncCoordinator.syncTrustedPeers
  → syncSingleTrustedPeer → LanSyncTransport.requestSync
  → SyncEngine.syncWithRemote → HttpRemoteSyncGateway
```

Key files:

- `packages/meshpad_core/lib/src/repositories/note_repository.dart`
- `packages/meshpad_core/lib/src/sync/sync_engine.dart`
- `packages/meshpad_core/lib/src/sync/remote_sync_gateway.dart`
- `packages/meshpad_core/lib/src/sync/sync_ack.dart` — outbox ack only when meta + attachments match
- `packages/meshpad_p2p/lib/src/lan/lan_sync_coordinator.dart`
- `packages/meshpad_p2p/lib/src/lan/lan_single_peer_sync.dart`
- `apps/meshpad/lib/core/providers/sync_providers.dart`

Rules:

- **Filesystem is source of truth**; Drift is an index
- Sync is **outbox-driven**; ack only after remote meta **and** attachments verified
- Do not change wire format without updating `docs/SYNC_WIRE.md`
- `createSyncTransport()` always returns `LanSyncTransport` (ADR 0003)
- **One host, one guest** for PIN pairing — host shows PIN/QR, guest enters/scans

## Resilience contract

| Failure | Expected behavior |
|---------|-------------------|
| One trusted peer unreachable | `LanSyncRunStatus.partial`; others sync |
| One note push fails | `failedPushNoteIds`; per-note outbox retry bump |
| Attachment push/pull fails | Note stays in outbox; meta may already be on peer |
| `SyncTransportException` | Do **not** bump outbox (transport unavailable) |
| Other batch-level exception | `OutboxProcessor.recordSyncFailure` (coordinator catch) |
| 401/403 on sync | Record `authFailureBody` / re-pair UX; do **not** `forgetPeer` (keep discovery cache) |
| Stream subscription | Always add `onError` + log via `MeshPadLog.warn` |

Pairing trust helpers (`packages/meshpad_p2p/lib/src/pairing_trust_handler.dart`):

- `trustDeviceFromPairingConfirm` — host trusts guest after HTTP confirm
- `trustDeviceFromPairingOffer` — guest trusts host after successful confirm

## Commands

```powershell
# First time
.\scripts\setup.ps1
.\scripts\bootstrap.ps1

# Daily dev (Windows)
.\dev.ps1

# Full local CI (day-to-day)
.\dev.ps1 -Test
# Release validate (includes format check — matches GitHub Release CI):
.\dev.ps1 -Test -WithFormat
# or: dart run melos run check   # analyze + tests only; no format

# Drift codegen after schema changes
cd packages/meshpad_core
dart run build_runner build --delete-conflicting-outputs

# Android release APK (+ meshpad-<version>.apk in repo root)
.\scripts\build-android.ps1
.\scripts\install-android-apk.ps1 -Build

# Windows release (exe + zip + setup installer in repo root)
.\scripts\build-windows.ps1
# or: .\dev.ps1 -Release   # same build + launch meshpad.exe
# or: dart run melos run build:windows

# LAN dual debug + merged logs
.\dev.ps1 -Device dual -CollectLogs
# Output: logs/latest-dual.log

# Firewall (Windows, admin once)
.\scripts\allow-meshpad-firewall.ps1

# Collect logs after session
.\scripts\collect-logs.ps1 -Source both

# Hub: deploy to production LAN host (build AOT on server)
.\scripts\deploy-hub.ps1
# Local hub AOT (same platform as host):
dart run melos run build:hub
```

## Release pre-flight (required before tag/push)

**Before creating or moving a release tag (`v*`), run the full validate pipeline locally and fix every failure.** Do not push a tag hoping CI will catch issues — release CI matches these steps exactly (see `.github/workflows/build-release.yml` job `validate`).

```powershell
# One command (bootstrap + codegen + l10n via Ensure-MeshPadBootstrapped)
.\dev.ps1 -Test -WithFormat

# Or step-by-step (same as GitHub Release validate):
dart run melos bootstrap
cd packages/meshpad_core; dart run build_runner build --delete-conflicting-outputs
cd ../../apps/meshpad; flutter gen-l10n
cd ../..
dart run melos run analyze    # --fatal-infos: warnings fail
dart run melos run format     # --set-exit-if-changed
dart run melos run test
dart run melos run flutter:test
```

Checklist:

1. **Analyze** — all 6 packages, zero issues (`unnecessary_import`, `strict_raw_type`, etc. count as errors with `--fatal-infos`)
2. **Format** — run `dart run melos run format:fix` if format check fails, then re-check
3. **Tests** — `meshpad_core`, `meshpad_p2p`, `meshpad_server`, then Flutter app tests
4. **Version** — `apps/meshpad/pubspec.yaml`, `kAppVersion` in `app_info.dart`, `CHANGELOG.md` section for the release
5. **Tag** — only after steps 1–4 pass; if CI fails after tag push, fix on `master`, then move the tag (`git tag -f vX.Y.Z`) and force-push the tag

After hub-related changes in a release, also redeploy hub per [LAN hub deployment](#lan-hub-deployment-1921688848).

## LAN hub deployment (192.168.88.48)

**Always keep the production LAN hub in sync** with hub-related changes in this repo. Do not leave hub work only on the dev machine — redeploy to the server before finishing the task (or explicitly report why deploy was skipped).

| Item | Value |
|------|--------|
| Host | `192.168.88.48` (SSH alias `pve-meshpad.48`, user `root`) |
| Service | `meshpad-hub.service` |
| Web UI | `http://192.168.88.48:8787/` |
| Data | `/var/lib/meshpad-hub` |
| Binary | `/usr/local/bin/meshpad-hub` |

After changes under `apps/meshpad_server/` or hub dependencies (`meshpad_core`, `meshpad_p2p`):

1. Run hub tests: `cd apps/meshpad_server && dart test`
2. Deploy: `.\scripts\deploy-hub.ps1` (packs workspace, builds AOT on server, restarts systemd)
   - Or manually: pack source per `scripts/hub-workspace-pubspec.yaml`, `dart compile exe bin/meshpad_server.dart -o meshpad-hub`, `install-hub-ubuntu.sh`
3. Smoke-check: `curl http://127.0.0.1:8787/hub/status` and open `/` (QR + sync badge)

Release CI also produces `meshpad-hub-<version>-linux-x64` (job `build-hub-linux`).

Full guide: [docs/HUB.md](docs/HUB.md). Install script: [scripts/install-hub-ubuntu.sh](scripts/install-hub-ubuntu.sh).

If SSH to `192.168.88.48` is unavailable, say so in the task summary — do not assume deploy succeeded.

## Testing

| Layer | Command | Location |
|-------|---------|----------|
| Core + P2P | `melos run test` | `packages/*/test/` |
| Flutter app | `melos run flutter:test` | `apps/meshpad/test/` |
| LAN harness | `lan_sync_test.dart`, `pipeline_e2e_test.dart` | `packages/meshpad_p2p/test/` |

When changing sync behavior:

1. Add or extend **package-level** tests with `LanPeerServer` harness
2. Run `.\dev.ps1 -Test` before commit
3. For pairing/sync regressions: `.\dev.ps1 -Device dual -CollectLogs`

Priority test areas: outbox retry, attachment partial sync, coordinator partial peers, pairing confirm HTTP codes.

Benchmark tests (opt-in): `cd packages/meshpad_core && dart test --tags benchmark`

## Clean Code refactor (Wave 2)

MeshPad is **Dart/Flutter**, not Python — use `dart analyze`, `dart format`, and `flutter_lints`, not PEP8/mypy/pytest.

**Refactor = structure only.** Do not change wire format (`docs/SYNC_WIRE.md`), sync semantics, or outbox ack rules unless fixing a documented bug in the debt register.

### Workflow

1. Read surrounding code; match naming and patterns.
2. One PR-sized change per file or subsystem.
3. Run `.\dev.ps1 -Test -WithFormat` before commit.
4. No behavior change — existing tests must pass unchanged.

### Priority targets (see [ROADMAP.md](ROADMAP.md) Wave 2)

| Priority | File | ~lines | Action |
|----------|------|--------|--------|
| P0 | `packages/meshpad_core/.../note_repository.dart` | 971 | `part` files: CRUD, outbox, reconcile, attachments |
| P0 | `packages/meshpad_p2p/.../lan_peer_server.dart` | 574 | Route table + handlers (extract `_route`) |
| P1 | `apps/meshpad/.../devices_sheet.dart` | 1570 | `pin_pairing_dialog.dart`, `device_card.dart` |
| P1 | `apps/meshpad/.../settings_sheet.dart` | 1416 | Section widgets |
| P1 | `apps/meshpad/.../feed_screen.dart` | 962 | Composer widget |

### Do not remove without ADR

- `native/` archived libp2p code (used in tests)
- `scripts/build-native-ffi*` (documented in `docs/LIBP2P.md`)
- `packages/meshpad_api_client` (Web dev stubs)
- `apps/meshpad/web/` (not productized, but not deleted ad hoc)

## Dart code quality

- `dart format .` — formatting (CI enforces)
- `dart analyze` — static analysis
- `flutter_lints` / `analysis_options.yaml` — lint rules
- **Clean refactor PRs:** structure and naming only; no wire-format or sync-semantics changes unless fixing a documented bug (see ROADMAP debt register)
- Split files >50 lines of unrelated logic; prefer `part` for large repositories
- Remove stale comments; doc comments only for non-obvious algorithms

## Do not change without ADR

- Removing archived libp2p code (used in tests)
- Web productization
- Threat model / commercial security scope (`docs/SECURITY.md`)
- Deleting `native/` without ADR

## Commit guidelines

- Message focuses on **why**, not file list
- Never commit: `data/`, `logs/`, `.env`, `tools/*.exe`, `*.db`, `build/`
- Run `.\dev.ps1 -Test` before committing pipeline changes

## Documentation map

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — layers and data flow
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — setup, troubleshooting
- [docs/SYNC_WIRE.md](docs/SYNC_WIRE.md) — LAN protocol
- [docs/HUB.md](docs/HUB.md) — Ubuntu LAN hub install and ops
- [ROADMAP.md](ROADMAP.md) — waves and debt register
- [CHANGELOG.md](CHANGELOG.md) — release history
