# Sync wire format (LAN + future libp2p)

MeshPad sync exchanges note data between peers. **Production (0.2.0)** uses **LAN HTTP/HTTPS** (`HttpRemoteSyncGateway` / `LanPeerServer`). Phase **B.2** will reuse the same payloads over libp2p streams; only the transport changes.

See also [LIBP2P.md](LIBP2P.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## Transport (current vs planned)

| Layer | LAN (production) | libp2p (backlog B.2) |
|-------|------------------|----------------------|
| Discovery | mDNS `:45837` UDP + `_meshpad._tcp` | Sidecar SSE `:45839` + mDNS browse |
| Pairing | HTTP `:45838` `/meshpad/p2p/pairing/*` | Noise channel |
| Sync data | HTTPS `:45840` (pinned) or HTTP `:45838` | libp2p push/pull |
| Auth | `X-MeshPad-Peer-Id` + `X-MeshPad-Auth-Token` | Same app token + Noise |

Endpoints under `/meshpad/p2p/*` (except pairing and health) require auth token from PIN pairing.

## Catalog

`GET /meshpad/p2p/catalog`

Response: JSON array of note heads:

```json
[
  {
    "id": "uuid",
    "updated_at": "2026-05-31T12:00:00.000Z",
    "deleted": false
  }
]
```

Dart: `NoteHead.toJson()` / `noteHeadsFromJsonList`.

## Note snapshot (push / pull)

`GET /meshpad/p2p/notes/<id>` — pull remote note.

`PUT /meshpad/p2p/notes/<id>` — push local note.

Body (`RemoteNoteSnapshot`):

```json
{
  "meta": {
    "schema_version": 1,
    "id": "uuid",
    "title": "Title",
    "created_at": "…",
    "updated_at": "…",
    "author": "device-name",
    "deleted": false,
    "deleted_at": null,
    "attachments": [
      { "name": "photo.jpg", "size": 12345, "mime": "image/jpeg", "sha256": "…" }
    ],
    "tags": ["work"]
  },
  "markdown": "# Body\n"
}
```

Response on push:

```json
{ "result": "applied" }
```

`result` is one of `applied`, `unchanged`, `rejected` (`NoteApplyResult`).

Merge rule: **LWW** on `meta.updated_at` (`mergeNoteMeta` in `meshpad_core`).

## Attachments

| Method | Path | Body |
|--------|------|------|
| GET | `/meshpad/p2p/notes/<id>/attachments/<name>` | raw bytes |
| PUT | same | raw bytes or chunked upload |

Large uploads use resumable headers (Phase C.3):

- `X-MeshPad-Upload-Offset`
- `X-MeshPad-Upload-Total`
- `X-MeshPad-Upload-Sha256`

Outbox clears only after remote has note meta and all attachment bytes verified (sha256).

## Sidecar API (B.2 bridge)

HTTP on `127.0.0.1:45839` (`HttpLibp2pNativeApi`):

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Sidecar alive |
| POST | `/v1/start` | `{ peer_id, display_name }` |
| POST | `/v1/stop` | Stop sidecar |
| POST | `/v1/sync` | `{ peer_id? }` — ping; **LAN fallback** until Rust push/pull |
| GET | `/v1/events` | SSE: `peer_discovered`, `sync_completed`, `sync_failed` |

Future: `/v1/sync` will run libp2p push/pull using the payloads above without changing `SyncEngine`.

## libp2p batch (planned)

Planned Rust message envelope for one sync round-trip:

```json
{
  "version": 1,
  "catalog": [ … NoteHead … ],
  "notes": [ … RemoteNoteSnapshot … ],
  "attachments": [
    { "note_id": "…", "name": "…", "sha256": "…", "bytes_base64": "…" }
  ]
}
```

Attachments may stay on separate streams for large files; catalog + meta always in the first frame.

## Testing

- LAN: `packages/meshpad_p2p/test/remote_sync_test.dart`, `lan_*_test.dart`
- libp2p transport: `libp2p_sync_transport_test.dart` (no Rust in CI unit tests)
- Rust sidecar: `cargo check` in CI (`.github/workflows/ci.yml`)
