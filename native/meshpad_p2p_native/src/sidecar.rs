//! MeshPad libp2p sidecar — HTTP bridge on `127.0.0.1` (PLAN §12 B.2 / 8.4 FFI).

use crate::{
    events::SidecarEvent, wire_attachment_store::WireAttachmentStore, wire_batch,
    wire_store::WireStore,
};
use std::{
    convert::Infallible,
    net::SocketAddr,
    sync::{Arc, Mutex},
};

use axum::{
    Json, Router,
    extract::State,
    response::{
        Sse,
        sse::{Event, KeepAlive},
    },
    routing::{get, post},
};
use futures::stream::Stream;
use serde::Deserialize;
use serde_json::{Value, json};
use tokio::sync::broadcast;
use tokio_stream::{StreamExt, wrappers::BroadcastStream};
use tower_http::trace::TraceLayer;
use tracing::info;

use crate::wire_store::note_id_from_snapshot;

pub const DEFAULT_PORT: u16 = 45839;
const DEFAULT_LAN_HTTP_PORT: u16 = 45839;
#[derive(Clone)]
pub struct SidecarState {
    inner: Arc<Mutex<RuntimeState>>,
    wire: Arc<Mutex<WireStore>>,
    attachments: Arc<Mutex<WireAttachmentStore>>,
    events: broadcast::Sender<SidecarEvent>,
    http_port: u16,
}

struct RuntimeState {
    peer_id: Option<String>,
    display_name: String,
    running: bool,
    p2p: Option<Arc<p2p::P2pController>>,
}

impl Default for RuntimeState {
    fn default() -> Self {
        Self {
            peer_id: None,
            display_name: "MeshPad".into(),
            running: false,
            p2p: None,
        }
    }
}

#[derive(Deserialize)]
pub struct StartRequest {
    peer_id: String,
    #[serde(default = "default_display_name")]
    display_name: String,
}

fn default_display_name() -> String {
    "MeshPad".into()
}

#[derive(Deserialize)]
pub struct SyncRequest {
    peer_id: Option<String>,
    remote_wire_base: Option<String>,
}

pub fn resolve_http_port() -> u16 {
    if let Ok(raw) = std::env::var("MESHPAD_LIBP2P_SIDECAR_PORT") {
        if let Ok(port) = raw.parse::<u16>() {
            return port;
        }
    }
    let args: Vec<String> = std::env::args().collect();
    let mut i = 1;
    while i < args.len() {
        if args[i] == "--port" {
            if let Some(next) = args.get(i + 1) {
                if let Ok(port) = next.parse::<u16>() {
                    return port;
                }
            }
            break;
        }
        i += 1;
    }
    DEFAULT_PORT
}

pub(crate) fn default_lan_http_port() -> u16 {
    std::env::var("MESHPAD_DEFAULT_PEER_WIRE_PORT")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(DEFAULT_LAN_HTTP_PORT)
}

pub fn new_sidecar_state(http_port: u16) -> SidecarState {
    let wire = Arc::new(Mutex::new(WireStore::default()));
    let attachments = Arc::new(Mutex::new(WireAttachmentStore::default()));
    let (tx, _) = broadcast::channel(64);
    SidecarState {
        inner: Arc::new(Mutex::new(RuntimeState::default())),
        wire,
        attachments,
        events: tx,
        http_port,
    }
}

pub fn build_router(http_port: u16) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/v1/start", post(start))
        .route("/v1/stop", post(stop))
        .route("/v1/sync", post(sync))
        .route("/v1/wire/catalog", get(wire_catalog))
        .route("/v1/wire/push", post(wire_push))
        .route("/v1/wire/pull", post(wire_pull))
        .route("/v1/wire/attachment/push", post(wire_attachment_push))
        .route("/v1/wire/attachment/pull", post(wire_attachment_pull))
        .route("/v1/wire/batch/export", get(wire_batch_export))
        .route("/v1/wire/batch/import", post(wire_batch_import))
        .route("/v1/events", get(events_sse))
        .layer(TraceLayer::new_for_http())
        .with_state(new_sidecar_state(http_port))
}

/// Binds `127.0.0.1:http_port` (or ephemeral port when `http_port == 0`) and serves until error.
pub async fn run(http_port: u16) -> Result<(), std::io::Error> {
    let listener = bind_listener(http_port).await?;
    let addr = listener.local_addr()?;
    info!("meshpad libp2p sidecar listening on http://{addr}");
    axum::serve(listener, build_router(addr.port())).await.map(|_| ())
}

/// Same as [run] but stops when `shutdown` completes (PLAN 8.4 embedded FFI).
pub async fn run_until_shutdown(
    http_port: u16,
    shutdown: impl std::future::Future<Output = ()> + Send + 'static,
) -> Result<(), std::io::Error> {
    let listener = bind_listener(http_port).await?;
    let addr = listener.local_addr()?;
    info!("meshpad libp2p sidecar (embedded) on http://{addr}");
    axum::serve(listener, build_router(addr.port()))
        .with_graceful_shutdown(shutdown)
        .await
        .map(|_| ())
}

pub async fn bind_listener(http_port: u16) -> Result<tokio::net::TcpListener, std::io::Error> {
    let addr = SocketAddr::from(([127, 0, 0, 1], http_port));
    tokio::net::TcpListener::bind(addr).await
}

async fn health(State(state): State<SidecarState>) -> Json<Value> {
    Json(crate::sidecar_api::health_json(&state).await)
}

async fn start(
    State(state): State<SidecarState>,
    Json(body): Json<StartRequest>,
) -> Json<Value> {
    info!("started peer_id={} (libp2p swarm)", body.peer_id);
    Json(crate::sidecar_api::start_json(&state, body).await)
}

async fn stop(State(state): State<SidecarState>) -> Json<Value> {
    Json(crate::sidecar_api::stop_json(&state).await)
}

async fn wire_catalog(State(state): State<SidecarState>) -> Json<Value> {
    Json(crate::sidecar_api::wire_catalog_json(&state))
}

#[derive(Deserialize)]
pub struct WirePushRequest {
    peer_id: Option<String>,
    #[serde(default)]
    snapshot: Value,
}

async fn wire_push(
    State(state): State<SidecarState>,
    Json(body): Json<WirePushRequest>,
) -> Json<Value> {
    Json(crate::sidecar_api::wire_push_json(&state, body))
}

#[derive(Deserialize)]
pub struct WirePullRequest {
    peer_id: Option<String>,
    #[serde(default)]
    note_ids: Vec<String>,
}

pub(crate) const DEFAULT_TLS_PORT: u16 = 45840;

#[derive(Deserialize)]
pub struct WireAttachmentPushRequest {
    peer_id: Option<String>,
    note_id: String,
    name: String,
    bytes_base64: String,
}

async fn wire_attachment_push(
    State(state): State<SidecarState>,
    Json(body): Json<WireAttachmentPushRequest>,
) -> Json<Value> {
    Json(crate::sidecar_api::wire_attachment_push_json(&state, body))
}

#[derive(Deserialize)]
pub struct WireAttachmentPullRequest {
    peer_id: Option<String>,
    note_id: String,
    name: String,
}

async fn wire_attachment_pull(
    State(state): State<SidecarState>,
    Json(body): Json<WireAttachmentPullRequest>,
) -> Result<Json<Value>, (axum::http::StatusCode, Json<Value>)> {
    match crate::sidecar_api::wire_attachment_pull_json(&state, body) {
        Ok(value) => {
            if value.get("status").and_then(|v| v.as_str()) == Some("not_found") {
                Err((axum::http::StatusCode::NOT_FOUND, Json(value)))
            } else {
                Ok(Json(value))
            }
        }
        Err(message) => Err((
            axum::http::StatusCode::BAD_REQUEST,
            Json(json!({ "status": "error", "message": message })),
        )),
    }
}

async fn wire_batch_export(State(state): State<SidecarState>) -> Json<Value> {
    Json(crate::sidecar_api::wire_batch_export_json(&state))
}

async fn wire_batch_import(
    State(state): State<SidecarState>,
    Json(body): Json<Value>,
) -> Json<Value> {
    Json(crate::sidecar_api::wire_batch_import_json(&state, body))
}

async fn wire_pull(
    State(state): State<SidecarState>,
    Json(body): Json<WirePullRequest>,
) -> Json<Value> {
    Json(crate::sidecar_api::wire_pull_json(&state, body))
}

pub(crate) fn normalize_wire_base(base: &str) -> String {
    let trimmed = base.trim();
    if trimmed.ends_with('/') {
        trimmed.to_string()
    } else {
        format!("{trimmed}/")
    }
}

pub(crate) async fn import_wire_from_http(
    base: &str,
    wire: &Arc<Mutex<WireStore>>,
    attachments: &Arc<Mutex<WireAttachmentStore>>,
) -> Result<u32, String> {
    let base = normalize_wire_base(base);
    let client = reqwest::Client::new();
    let batch_url = format!("{base}v1/wire/batch/export");
    if let Ok(resp) = client.get(&batch_url).send().await {
        if resp.status().is_success() {
            if let Ok(batch) = resp.json::<Value>().await {
                let imported = {
                    let mut w = wire.lock().expect("wire lock");
                    let mut a = attachments.lock().expect("attachments lock");
                    wire_batch::import_batch(&batch, &mut w, &mut a)
                };
                if imported > 0 {
                    return Ok(imported);
                }
            }
        }
    }

    let catalog: Vec<Value> = client
        .get(format!("{base}v1/wire/catalog"))
        .send()
        .await
        .map_err(|e| e.to_string())?
        .json()
        .await
        .map_err(|e| e.to_string())?;

    let note_ids: Vec<String> = catalog
        .iter()
        .filter_map(|head| head.get("id").and_then(|id| id.as_str()).map(str::to_string))
        .collect();

    if note_ids.is_empty() {
        return Ok(0);
    }

    let pull: Value = client
        .post(format!("{base}v1/wire/pull"))
        .json(&json!({ "note_ids": note_ids }))
        .send()
        .await
        .map_err(|e| e.to_string())?
        .json()
        .await
        .map_err(|e| e.to_string())?;

    let notes = pull
        .get("notes")
        .and_then(|n| n.as_array())
        .cloned()
        .unwrap_or_default();

    Ok(wire
        .lock()
        .expect("wire lock")
        .import_snapshots(notes))
}

pub(crate) async fn push_wire_batch_to_http(
    base: &str,
    wire: &Arc<Mutex<WireStore>>,
    attachments: &Arc<Mutex<WireAttachmentStore>>,
) -> Result<u32, String> {
    let base = normalize_wire_base(base);
    let batch = {
        let w = wire.lock().expect("wire lock");
        let a = attachments.lock().expect("attachments lock");
        wire_batch::export_batch(&w, &a)
    };
    let client = reqwest::Client::new();
    let resp: Value = client
        .post(format!("{base}v1/wire/batch/import"))
        .json(&batch)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .json()
        .await
        .map_err(|e| e.to_string())?;
    Ok(resp.get("imported").and_then(|v| v.as_u64()).unwrap_or(0) as u32)
}

async fn sync(State(state): State<SidecarState>, Json(body): Json<SyncRequest>) -> Json<Value> {
    Json(crate::sidecar_api::sync_json(&state, body).await)
}

async fn events_sse(
    State(state): State<SidecarState>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let rx = state.events.subscribe();
    let stream = BroadcastStream::new(rx).filter_map(|result| match result {
        Ok(event) => {
            let payload = serde_json::to_string(&event).ok()?;
            Some(Ok(Event::default().data(payload)))
        }
        Err(_) => None,
    });

    Sse::new(stream).keep_alive(KeepAlive::default())
}

#[cfg(test)]
mod tests {
    use super::*;
    use wire_store::note_id_from_snapshot;

    #[test]
    fn normalize_wire_base_adds_trailing_slash() {
        assert_eq!(
            normalize_wire_base("http://127.0.0.1:45839"),
            "http://127.0.0.1:45839/"
        );
    }

    #[test]
    fn note_id_from_snapshot_reads_meta_id() {
        let snapshot = json!({
            "meta": { "id": "abc-123" },
            "markdown": ""
        });
        assert_eq!(note_id_from_snapshot(&snapshot).as_deref(), Some("abc-123"));
    }
}
