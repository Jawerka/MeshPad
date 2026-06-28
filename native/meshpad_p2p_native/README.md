# MeshPad native libp2p crate (archived)

> **Archived** — not built in CI/release (ADR 0003). See [docs/LIBP2P.md](../../docs/LIBP2P.md).

Rust binary implementing the localhost sidecar HTTP API consumed by
`HttpLibp2pNativeApi` (`packages/meshpad_p2p`).

**Status:** HTTP sidecar + **libp2p** swarm (`rust-libp2p` backend): mDNS, identify (`meshpad/<peer_id>/…`), wire sync on `/meshpad/wire/1.0.0`, SSE `peer_discovered` with `lan_host` / `wire_base`.

`POST /v1/sync` supports:

- `remote_wire_base` — HTTP wire batch import/export when available (catalog/pull fallback)
- `peer_id` only — libp2p `get_batch` / `push_batch` when connected (legacy catalog/pull/push fallback)

CI: `cargo test` / `cargo check` on `ubuntu-latest`.

## API (matches Dart sidecar)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | `{ status, backend, running, wire_notes, http_port }` |
| POST | `/v1/start` | `{ peer_id, display_name }` |
| POST | `/v1/stop` | stop |
| POST | `/v1/sync` | `{ peer_id?, remote_wire_base? }` → `{ wire_imported, wire_pushed }` + SSE `sync_completed` |
| GET | `/v1/wire/catalog` | note heads ([SYNC_WIRE.md](../../docs/SYNC_WIRE.md)) |
| POST | `/v1/wire/push` | `{ peer_id?, snapshot }` |
| POST | `/v1/wire/pull` | `{ peer_id?, note_ids[] }` → `{ notes: [...] }` |
| GET | `/v1/wire/batch/export` | full `WireSyncBatch` envelope |
| POST | `/v1/wire/batch/import` | `{ batch }` → `{ imported }` |
| GET | `/v1/events` | SSE (`peer_discovered`, `sync_completed`) |

Default bind: `http://127.0.0.1:45839`

Override: `--port 45840` or `MESHPAD_LIBP2P_SIDECAR_PORT=45840`

Peer wire URL hint port (LAN): `MESHPAD_DEFAULT_PEER_WIRE_PORT` (default `45839`)

## Build & run

Requires [Rust stable](https://rustup.rs/) (not bundled with Flutter).

```bash
cd native/meshpad_p2p_native
cargo build --release
./target/release/meshpad_p2p_sidecar
# optional in-process embed (PLAN 8.4):
cargo build --lib --release   # → target/release/libmeshpad_p2p_native.so (or .dll)
```

### FFI (8.4)

| Symbol | Description |
|--------|-------------|
| `meshpad_ffi_start_embedded(port)` | Bind loopback HTTP sidecar; returns port (`0` = ephemeral) |
| `meshpad_ffi_stop_embedded()` | Graceful shutdown |
| `meshpad_ffi_embedded_port()` | Current port or `0` |
| `meshpad_ffi_version()` | Version C string |
| `meshpad_ffi_start_direct()` | In-process API without TCP (`1` = ok) |
| `meshpad_ffi_request(method, path, body)` | JSON dispatch (`0`=GET, `1`=POST) |
| `meshpad_ffi_poll_event()` | Next SSE-style event as JSON, or null |
| `meshpad_ffi_free_string(ptr)` | Free strings from request/poll |

Dart: bundled desktop builds auto-load direct FFI; override with `MESHPAD_LIBP2P_FFI=1` — see [docs/LIBP2P.md](../../docs/LIBP2P.md).

**Desktop bundle:** `scripts/build-native-ffi.ps1` (Windows) or `scripts/build-native-ffi.sh` (Linux), then `flutter build windows|linux --release`.

**Android bundle:** `scripts/build-native-ffi-android.sh` (needs `cargo-ndk` + NDK), then `flutter build apk --release`. See `apps/meshpad/android/app/src/main/jniLibs/README.md`.

Or use the Dart stub (no Rust):

```bash
dart run meshpad_p2p_sidecar
```

Environment:

- `MESHPAD_LIBP2P_SIDECAR_URL` — sidecar base URL for the app
- `MESHPAD_LIBP2P_SIDECAR_PORT` — listen port (same as `--port`)
- `MESHPAD_PEER_WIRE_BASES` — JSON map peer id → remote wire URL (see [DEVELOPMENT.md](../../docs/DEVELOPMENT.md))

See [docs/LIBP2P.md](../../docs/LIBP2P.md).
