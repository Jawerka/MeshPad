# MeshPad native libp2p crate (Phase B.1 / B.2)

Rust binary implementing the localhost sidecar HTTP API consumed by
`HttpLibp2pNativeApi` (`packages/meshpad_p2p`).

**Status:** HTTP sidecar stub (`rust-stub` backend). libp2p mDNS / Noise / push-pull
land in follow-up commits. Not required for CI (`melos run check`).

## API (matches Dart sidecar)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | `{ status, backend, running }` |
| POST | `/v1/start` | `{ peer_id, display_name }` |
| POST | `/v1/stop` | stop |
| POST | `/v1/sync` | `{ peer_id? }` → SSE `sync_completed` |
| GET | `/v1/events` | SSE stream |

Default bind: `http://127.0.0.1:45839`

## Build & run

Requires [Rust stable](https://rustup.rs/) (not bundled with Flutter).

```bash
cd native/meshpad_p2p_native
cargo build --release
./target/release/meshpad_p2p_sidecar
```

Or use the Dart stub (no Rust):

```bash
dart run meshpad_p2p_sidecar
```

Point the app at a custom URL: `MESHPAD_LIBP2P_SIDECAR_URL=http://127.0.0.1:45839`

## Planned libp2p surface

| Method | Purpose |
|--------|---------|
| `start` | Listen, announce, load identity keys |
| `discover` | mDNS peer announcements |
| `pair` | Noise-encrypted PIN exchange |
| `push` / `pull` | Sync batches (existing MeshPad codec) |

See [docs/LIBP2P.md](../../docs/LIBP2P.md).
