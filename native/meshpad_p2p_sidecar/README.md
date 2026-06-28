# MeshPad libp2p sidecar (archived)

> **Archived** — not used in production (ADR 0003). See [docs/LIBP2P.md](../../docs/LIBP2P.md).

Localhost HTTP bridge between Flutter and the Rust libp2p backend.

## Run

```bash
dart run meshpad_p2p_sidecar
# http://127.0.0.1:45839
```

Alternative (Rust stub, requires [Rust](https://rustup.rs/)):

```bash
cd ../meshpad_p2p_native && cargo run --release
```

## Protocol

| Method | Path | Body |
|--------|------|------|
| GET | `/health` | — |
| POST | `/v1/start` | `{ "peer_id", "display_name" }` — starts mDNS browse-only |
| POST | `/v1/stop` | `{}` |
| POST | `/v1/sync` | `{ "peer_id"?, "remote_wire_base"? }` |
| GET | `/v1/wire/catalog` | `[]` — catalog heads stub ([SYNC_WIRE.md](../../docs/SYNC_WIRE.md)) |
| POST | `/v1/wire/push` | `{ "peer_id"?, "snapshot" }` |
| POST | `/v1/wire/pull` | `{ "peer_id"?, "note_ids": [] }` |
| GET | `/v1/events` | SSE (`peer_discovered`, `sync_completed`, `sync_failed`) |

### SSE `peer_discovered`

```json
{
  "type": "peer_discovered",
  "peer_id": "...",
  "display_name": "...",
  "lan_host": "192.168.1.10",
  "http_port": 45838,
  "tls_port": 45840,
  "wire_base": "http://192.168.1.10:45839/"
}
```

`POST /v1/sync` body may include `remote_wire_base` to import wire catalog from another sidecar (see [SYNC_WIRE.md](../../docs/SYNC_WIRE.md)).

Dart client: `HttpLibp2pNativeApi` in `packages/meshpad_p2p`.

When `SyncTransportKind.libp2p` is selected, the app auto-connects if the sidecar responds on port **45839**. Override with env `MESHPAD_LIBP2P_SIDECAR_URL` or `--dart-define=MESHPAD_LIBP2P_SIDECAR_URL=...`.

**Status:** Dart sidecar runs mDNS discovery; sync still uses LAN fallback in the app until Rust push/pull lands.
