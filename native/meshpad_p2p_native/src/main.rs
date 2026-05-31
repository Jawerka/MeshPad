//! MeshPad libp2p sidecar — HTTP bridge on `127.0.0.1:45839` (PLAN §12 B.2).
//!
//! Matches the Dart sidecar contract consumed by `HttpLibp2pNativeApi`.
//! Sync still delegates to LAN until push/pull over libp2p is implemented.

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
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use tokio::sync::broadcast;
use tokio_stream::{StreamExt, wrappers::BroadcastStream};
use tower_http::trace::TraceLayer;
use tracing::info;

const DEFAULT_PORT: u16 = 45839;

#[derive(Clone, Default)]
struct SidecarState {
    inner: Arc<Mutex<RuntimeState>>,
    events: broadcast::Sender<SidecarEvent>,
}

#[derive(Default)]
struct RuntimeState {
    peer_id: Option<String>,
    display_name: String,
    running: bool,
}

#[derive(Clone, Debug, Serialize)]
struct SidecarEvent {
    #[serde(rename = "type")]
    kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    peer_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    display_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    note_count: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    message: Option<String>,
}

#[derive(Deserialize)]
struct StartRequest {
    peer_id: String,
    #[serde(default = "default_display_name")]
    display_name: String,
}

fn default_display_name() -> String {
    "MeshPad".into()
}

#[derive(Deserialize)]
struct SyncRequest {
    peer_id: Option<String>,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter("meshpad_p2p_native=info,tower_http=info")
        .init();

    let (tx, _) = broadcast::channel(64);
    let state = SidecarState {
        inner: Arc::new(Mutex::new(RuntimeState::default())),
        events: tx,
    };

    let app = Router::new()
        .route("/health", get(health))
        .route("/v1/start", post(start))
        .route("/v1/stop", post(stop))
        .route("/v1/sync", post(sync))
        .route("/v1/events", get(events))
        .layer(TraceLayer::new_for_http())
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], DEFAULT_PORT));
    info!("meshpad libp2p sidecar listening on http://{addr}");
    let listener = tokio::net::TcpListener::bind(addr).await.expect("bind");
    axum::serve(listener, app).await.expect("serve");
}

async fn health(State(state): State<SidecarState>) -> Json<Value> {
    let runtime = state.inner.lock().expect("lock");
    Json(json!({
        "status": "ok",
        "backend": "rust-stub",
        "running": runtime.running,
    }))
}

async fn start(
    State(state): State<SidecarState>,
    Json(body): Json<StartRequest>,
) -> Json<Value> {
    {
        let mut runtime = state.inner.lock().expect("lock");
        runtime.peer_id = Some(body.peer_id.clone());
        runtime.display_name = body.display_name.clone();
        runtime.running = true;
    }
    info!("started peer_id={}", body.peer_id);
    Json(json!({ "status": "started" }))
}

async fn stop(State(state): State<SidecarState>) -> Json<Value> {
    {
        let mut runtime = state.inner.lock().expect("lock");
        runtime.running = false;
    }
    Json(json!({ "status": "stopped" }))
}

async fn sync(
    State(_state): State<SidecarState>,
    Json(body): Json<SyncRequest>,
) -> Json<Value> {
    // Real libp2p push/pull will run here (B.2). Until then Dart uses LAN fallback.
    Json(json!({
        "status": "delegated",
        "backend": "rust-stub",
        "lan_fallback": true,
        "peer_id": body.peer_id,
    }))
}

async fn events(
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
