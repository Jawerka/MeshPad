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
| `apps/meshpad_server` | Headless REST/SSE (dev only) |
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
| 401/403 on sync | `forgetPeer`; user must re-pair |
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

# Full local CI
.\dev.ps1 -Test
# or: dart run melos run check

# Drift codegen after schema changes
cd packages/meshpad_core
dart run build_runner build --delete-conflicting-outputs

# Android release APK
.\scripts\build-android.ps1
.\scripts\install-android-apk.ps1 -Build

# LAN dual debug + merged logs
.\dev.ps1 -Device dual -CollectLogs
# Output: logs/latest-dual.log

# Firewall (Windows, admin once)
.\scripts\allow-meshpad-firewall.ps1

# Collect logs after session
.\scripts\collect-logs.ps1 -Source both
```

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
- [ROADMAP.md](ROADMAP.md) — waves and debt register
- [CHANGELOG.md](CHANGELOG.md) — release history
