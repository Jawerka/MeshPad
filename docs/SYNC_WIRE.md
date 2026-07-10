# Sync wire format (LAN)

MeshPad sync exchanges note data between peers. **Production** uses **LAN HTTP/HTTPS** only ([ADR 0003](ADR/0003-simplicity-lan-git.md)).

See [ARCHITECTURE.md](ARCHITECTURE.md), [GIT_SYNC.md](GIT_SYNC.md).

## Transport

| Layer | LAN (production) |
|-------|------------------|
| Discovery | mDNS `:45837` UDP + `_meshpad._tcp` |
| Pairing | HTTP `:45838` `/meshpad/p2p/pairing/*` |
| Sync data | HTTP `:45838` or HTTPS `:45840` (pinned) |
| Auth | `X-MeshPad-Peer-Id` + `X-MeshPad-Auth-Token` + Ed25519 request signature |
| Payload | Optional AES-256-GCM (`X-MeshPad-Payload-Enc: meshpad-payload-v1`) |

### Payload encryption (1.0)

When paired with an auth token, JSON bodies (catalog, note snapshot, apply result) may be encrypted:

- Key: `HKDF-SHA256(auth_token, salt="meshpad-payload-v1", info=sorted_peer_ids)`
- Envelope: `{"enc":"meshpad-payload-v1","nonce":"...","ciphertext":"..."}`
- Content-Type: `application/meshpad+json`

Peers without the header continue to receive plain JSON (re-pair to enable encryption).

Endpoints under `/meshpad/p2p/*` (except pairing and health) require auth token from PIN pairing.

libp2p is **archived** — see [LIBP2P.md](LIBP2P.md).

### Request signing (волна 2.8)

When the trusted peer record includes `signing_public_key` (exchanged during PIN pairing), every authenticated request must also send:

| Header | Value |
|--------|--------|
| `X-MeshPad-Timestamp` | UTC ISO-8601 (max skew ±5 min) |
| `X-MeshPad-Signature` | Base64 Ed25519 signature |

Canonical message (UTF-8, newline-separated):

```text
v1
<peer_id>
<timestamp>
<METHOD>
<path>
```

Peers paired before 2.8 may omit signing keys; token-only auth still works until re-paired.

### Auth failure bodies

HTTP status codes stay `401` / `403`. Response body identifies the reason:

| Body | Status | Meaning |
|------|--------|---------|
| `unauthorized:missing_peer_id` | 401 | Missing `X-MeshPad-Peer-Id` |
| `unauthorized:token` | 401 | Missing or wrong auth token |
| `unauthorized:missing_signature` | 401 | Trusted peer expects signing; headers absent |
| `unauthorized:signature` | 401 | Invalid Ed25519 signature |
| `unauthorized:clock_skew` | 401 | Timestamp outside ±5 min window |
| `peer not trusted` | 403 | Caller peer id not in trusted store |
| `unauthorized` | 401 | Legacy clients (treated as token failure) |

## Cascade sync (multi-peer orchestration)

After a successful bidirectional sync session, the initiator may nudge the peer to sync remaining trusted devices (epidemic propagation, one HTTP nudge per direct sync).

`POST /meshpad/p2p/sync/cascade`

Request body (JSON):

```json
{
  "excludePeerIds": ["initiator-peer-id", "relay-peer-id"],
  "excludePeerId": "legacy-single-id",
  "hopLimit": 7
}
```

| Field | Meaning |
|-------|---------|
| `excludePeerIds` | Peers already visited in this cascade chain (do not sync again) |
| `excludePeerId` | Legacy single exclude; merged into `excludePeerIds` |
| `hopLimit` | Remaining cascade hops the receiver may forward (0 = sync only, no further cascade) |

Response: `{"status":"accepted"}` — sync runs asynchronously on the receiver.

Receiver behavior:

1. Sync all trusted peers except `excludePeerIds`.
2. If `hopLimit > 0`, after each successful peer send cascade with updated `excludePeerIds` (add self) and `hopLimit - 1`.

Initiator (app/hub) uses profile defaults: `normal` cascade hop limit 8, max 2 concurrent peers; `gentle` hop limit 1, sequential.

Offline peers (`unreachable`) are skipped silently; they catch up via outbox + periodic auto-sync when online.

## Catalog

`GET /meshpad/p2p/catalog`

Clients may send `Accept-Encoding: gzip`. When the JSON body is at least **256 bytes**, the server responds with `Content-Encoding: gzip` and a gzip-compressed JSON array (same schema). Smaller catalogs stay uncompressed JSON. Implementation: `lan_catalog_body.dart` / `HttpRemoteSyncGateway.fetchCatalog`.

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

### Merge strategy (0.3.x)

1. **Different `updated_at`:** last-write-wins — newer `meta.updated_at` wins (`resolveNoteConflict` → `appliedRemote` / `appliedLocal`).
2. **Same `updated_at`, different title/body/tags:** **conflict copy** — local note stays; remote payload saved as  
   `notes/<id>/<id>.conflict-<timestamp>.md` (JSON front matter + markdown). UI shows a **Conflict** badge.
3. **Identical content:** no change (`unchanged`).

`meta.json` may include optional `revision` (incremented on each local save) and `vector_clock` (reserved for future merge). Wire payloads remain backward compatible with 0.2.0 peers that omit these fields.

Implementation: `conflict_resolver.dart`, `NoteRepository.applyRemoteMerge`.

### Delta sync (catalog-first)

1. Exchange **catalog** (`GET /meshpad/p2p/catalog`) — array of `{ id, updated_at, deleted }`.
2. Compare each remote head to the local catalog (`noteHeadNeedsRemotePull` in `catalog_delta.dart`).
3. **Skip** `GET /meshpad/p2p/notes/<id>` when heads already match; still verify attachments if needed.
4. Fetch and merge only notes that are new or newer (or tombstone mismatch).

Push path already compares local vs remote catalog heads before `PUT`.

## PIN pairing QR (LAN, PLAN §11.4.3)

URI в QR на экране **хоста** (гость сканирует на Android):

```text
meshpad://pair?host=<lan-ip>&port=<http-port>&pin=<6-digit>[&tls=<tls-port>]
```

Гость: probe `host:port`, сверка PIN с `GET /meshpad/p2p/pairing/offer`, затем `POST /meshpad/p2p/pairing/confirm`.

## Web API (`meshpad_server`)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/notes?since=<ISO-8601>` | Active notes with `updated_at` ≥ since (catch-up after SSE gap) |
| GET | `/api/events` | SSE; optional header `Last-Event-ID` replays buffered events (max 500) |

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
| POST | `/v1/sync` | `{ peer_id?, remote_wire_base? }` — dev: import wire catalog from peer sidecar URL; then `sync_completed` SSE |
| GET | `/v1/wire/catalog` | Note heads (same shape as LAN catalog) |
| POST | `/v1/wire/push` | `{ peer_id?, snapshot }` — upsert one note snapshot |
| POST | `/v1/wire/pull` | `{ peer_id?, note_ids[] }` — return snapshots (`note_ids` empty = all) |
| POST | `/v1/wire/attachment/push` | `{ note_id, name, bytes_base64 }` — store attachment (≤16 MiB) |
| POST | `/v1/wire/attachment/pull` | `{ note_id, name }` → `{ bytes_base64 }` or 404 |
| GET | `/v1/wire/batch/export` | Full batch envelope (`version`, `catalog`, `notes`, `attachments`) |
| POST | `/v1/wire/batch/import` | Import batch → `{ imported }` |
| GET | `/v1/events` | SSE: `peer_discovered`, `sync_completed`, `sync_failed` |

`remote_wire_base` is a **dev harness** until libp2p fills the local wire store over the network. Production clients still use LAN for sync data.

Future: `/v1/sync` without `remote_wire_base` will run libp2p push/pull using the payloads above without changing `SyncEngine`.

## libp2p wire protocol (8.1 partial)

Rust sidecar (`meshpad_p2p_native`) speaks JSON request-response on libp2p protocol **`/meshpad/wire/1.0.0`**:

| `op` | Request | Response |
|------|---------|----------|
| `hello` | `{ peer_id, display_name }` | `hello_ack` |
| `get_catalog` | — | `{ heads: [NoteHead…] }` |
| `pull` | `{ note_ids: [] }` | `{ notes: [snapshot…] }` |
| `push` | `{ snapshot }` | `push_ack` |
| `get_batch` | — | `{ batch: WireSyncBatch }` |
| `push_batch` | `{ batch: WireSyncBatch }` | `{ imported: N }` (`batch_ack`) |

`POST /v1/sync` without `remote_wire_base` runs **libp2p batch sync** (`get_batch` → import → `push_batch`) when the peer is connected; falls back to catalog/pull/push. HTTP `remote_wire_base` uses batch export/import when available.

## Wire batch envelope (8.1)

HTTP sidecar (`GET /v1/wire/batch/export`, `POST /v1/wire/batch/import`). `importFromRemote` prefers batch when the remote supports export.

Envelope for one sync round-trip:

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

