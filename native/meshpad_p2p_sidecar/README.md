# MeshPad libp2p sidecar (Phase B.2)

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
| POST | `/v1/sync` | `{ "peer_id"? }` |
| GET | `/v1/events` | SSE (`peer_discovered`, `sync_completed`, `sync_failed`) |

### SSE `peer_discovered`

```json
{
  "type": "peer_discovered",
  "peer_id": "...",
  "display_name": "...",
  "lan_host": "192.168.1.10",
  "http_port": 45838,
  "tls_port": 45840
}
```

Dart client: `HttpLibp2pNativeApi` in `packages/meshpad_p2p`.

When `SyncTransportKind.libp2p` is selected, the app auto-connects if the sidecar responds on port **45839**. Override with env `MESHPAD_LIBP2P_SIDECAR_URL` or `--dart-define=MESHPAD_LIBP2P_SIDECAR_URL=...`.

**Status:** Dart sidecar runs mDNS discovery; sync still uses LAN fallback in the app until Rust push/pull lands.
