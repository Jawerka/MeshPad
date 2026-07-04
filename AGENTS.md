# AGENTS.md — Working with MeshPad

Guide for AI coding agents (Cursor, etc.) working in this repository.

## Project summary

MeshPad is a **local-first Markdown notebook** with a chat-style feed UI. Production sync is **LAN-only** (mDNS/UDP + HTTP/HTTPS, PIN pairing, encrypted payloads). **Git sync** is secondary (desktop, manual, no attachments).

Supported platforms: **Windows**, **Android**, Linux (CI compile). Not supported: iOS, macOS, Web product.

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
  → LanSyncTransport → SyncEngine.syncWithRemote → HttpRemoteSyncGateway
```

Key files:

- `packages/meshpad_core/lib/src/repositories/note_repository.dart`
- `packages/meshpad_core/lib/src/sync/sync_engine.dart`
- `packages/meshpad_core/lib/src/sync/remote_sync_gateway.dart`
- `packages/meshpad_p2p/lib/src/lan/lan_sync_coordinator.dart`
- `packages/meshpad_p2p/lib/src/lan/lan_single_peer_sync.dart`
- `apps/meshpad/lib/core/providers/sync_providers.dart`

Rules:

- **Filesystem is source of truth**; Drift is an index
- Sync is **outbox-driven**; ack only after remote meta + attachments verified
- Do not change wire format without updating `docs/SYNC_WIRE.md`
- `createSyncTransport()` always returns `LanSyncTransport` (ADR 0003)

## Commands

```powershell
# First time
.\scripts\setup.ps1
.\scripts\bootstrap.ps1

# Daily dev (Windows)
.\dev.ps1

# Full local CI (analyze + package tests + flutter tests)
.\dev.ps1 -Test
# or
dart run melos run check

# Drift codegen after schema changes
cd packages/meshpad_core
dart run build_runner build --delete-conflicting-outputs

# Android release APK
.\scripts\build-android.ps1
.\scripts\install-android-apk.ps1 -Build

# LAN dual debug (Win + phone)
.\dev.ps1 -Device dual

# Firewall (Windows, admin once)
.\scripts\allow-meshpad-firewall.ps1
```

## Testing

| Layer | Command | Location |
|-------|---------|----------|
| Core + P2P | `melos run test` | `packages/*/test/` |
| Flutter app | `melos run flutter:test` | `apps/meshpad/test/` |
| LAN harness | `lan_sync_test.dart`, `pipeline_e2e_test.dart` | `packages/meshpad_p2p/test/` |

When adding sync behavior, prefer **package-level integration tests** with `LanPeerServer` harness (see `lan_sync_test.dart`) over mocking the entire stack.

Benchmark tests (opt-in): `cd packages/meshpad_core && dart test --tags benchmark`

## Resilience conventions

- **Per-peer errors** must not abort sync for other trusted peers (`LanSyncRunStatus.partial`)
- **Per-attachment errors** must not abort note meta sync
- `SyncTransportException` → do not bump outbox retry; other errors → `OutboxProcessor.recordSyncFailure`
- Discovery event listeners need `onError` and try/catch in async handlers

## Do not change without ADR

- Removing archived libp2p code (used in tests)
- Web productization
- Threat model / commercial security scope (`docs/SECURITY.md`)

## Commit guidelines

- Focus commit message on **why**, not file list
- Never commit: `data/`, `.env`, `tools/*.exe`, `*.db`, `build/`
- Run `.\dev.ps1 -Test` before committing pipeline changes

## Documentation map

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — layers and data flow
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — setup, troubleshooting
- [docs/SYNC_WIRE.md](docs/SYNC_WIRE.md) — LAN protocol
- [ROADMAP.md](ROADMAP.md) — planned waves
- [CHANGELOG.md](CHANGELOG.md) — release history
