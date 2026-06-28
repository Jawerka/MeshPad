//! In-process JSON API for sidecar routes (PLAN 8.4 direct FFI).

use std::sync::Arc;

use serde::Deserialize;
use serde_json::{Value, json};

use crate::{
    p2p::P2pConfig,
    sidecar::{
        StartRequest, SyncRequest, WireAttachmentPullRequest, WireAttachmentPushRequest,
        WirePullRequest, WirePushRequest, default_lan_http_port, import_wire_from_http,
        push_wire_batch_to_http, SidecarState, DEFAULT_TLS_PORT,
    },
};

use base64::{engine::general_purpose::STANDARD, Engine};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HttpMethod {
    Get,
    Post,
}

/// Dispatches a sidecar route without loopback HTTP.
pub async fn dispatch_json(
    state: &SidecarState,
    method: HttpMethod,
    path: &str,
    body: Option<Value>,
) -> Result<Value, String> {
    let path = path.trim();
    match (method, path) {
        (HttpMethod::Get, "/health") => Ok(health_json(state).await),
        (HttpMethod::Post, "/v1/start") => {
            let body: StartRequest = parse_body(body)?;
            Ok(start_json(state, body).await)
        }
        (HttpMethod::Post, "/v1/stop") => Ok(stop_json(state).await),
        (HttpMethod::Post, "/v1/sync") => {
            let body: SyncRequest = parse_body(body)?;
            Ok(sync_json(state, body).await)
        }
        (HttpMethod::Get, "/v1/wire/catalog") => Ok(wire_catalog_json(state)),
        (HttpMethod::Post, "/v1/wire/push") => {
            let body: WirePushRequest = parse_body(body)?;
            Ok(wire_push_json(state, body))
        }
        (HttpMethod::Post, "/v1/wire/pull") => {
            let body: WirePullRequest = parse_body(body)?;
            Ok(wire_pull_json(state, body))
        }
        (HttpMethod::Get, "/v1/wire/batch/export") => Ok(wire_batch_export_json(state)),
        (HttpMethod::Post, "/v1/wire/batch/import") => {
            let body = body.ok_or_else(|| "missing batch body".to_string())?;
            Ok(wire_batch_import_json(state, body))
        }
        (HttpMethod::Post, "/v1/wire/attachment/push") => {
            let body: WireAttachmentPushRequest = parse_body(body)?;
            Ok(wire_attachment_push_json(state, body))
        }
        (HttpMethod::Post, "/v1/wire/attachment/pull") => {
            let body: WireAttachmentPullRequest = parse_body(body)?;
            wire_attachment_pull_json(state, body)
        }
        _ => Err(format!("unsupported route {method:?} {path}")),
    }
}

fn parse_body<T: for<'de> Deserialize<'de>>(body: Option<Value>) -> Result<T, String> {
    let value = body.ok_or_else(|| "missing JSON body".to_string())?;
    serde_json::from_value(value).map_err(|e| e.to_string())
}

pub async fn health_json(state: &SidecarState) -> Value {
    let runtime = state.inner.lock().expect("lock");
    let wire_notes = state.wire.lock().expect("wire lock").len();
    let wire_attachments = state.attachments.lock().expect("attachments lock").len();
    json!({
        "status": "ok",
        "backend": "rust-libp2p",
        "running": runtime.running,
        "wire_notes": wire_notes,
        "wire_attachments": wire_attachments,
        "libp2p": runtime.p2p.is_some(),
        "http_port": state.http_port,
        "transport": "ffi_direct",
    })
}

pub async fn start_json(state: &SidecarState, body: StartRequest) -> Value {
    {
        let mut runtime = state.inner.lock().expect("lock");
        runtime.peer_id = Some(body.peer_id.clone());
        runtime.display_name = body.display_name.clone();
        runtime.running = true;
        runtime.p2p = Some(Arc::new(crate::p2p::spawn(
            state.wire.clone(),
            state.attachments.clone(),
            body.peer_id.clone(),
            body.display_name.clone(),
            P2pConfig {
                events: state.events.clone(),
                http_listen_port: state.http_port,
                default_lan_http_port: default_lan_http_port(),
                default_tls_port: DEFAULT_TLS_PORT,
            },
        )));
    }
    json!({ "status": "started", "libp2p": true })
}

pub async fn stop_json(state: &SidecarState) -> Value {
    let p2p = {
        let mut runtime = state.inner.lock().expect("lock");
        runtime.running = false;
        runtime.p2p.take()
    };
    if let Some(controller) = p2p {
        controller.stop().await;
    }
    json!({ "status": "stopped" })
}

fn wire_catalog_json(state: &SidecarState) -> Value {
    let heads = state.wire.lock().expect("wire lock").catalog_heads();
    Value::Array(heads)
}

fn wire_push_json(state: &SidecarState, body: WirePushRequest) -> Value {
    let accepted = state
        .wire
        .lock()
        .expect("wire lock")
        .upsert(body.snapshot);
    json!({
        "status": if accepted { "accepted" } else { "ignored" },
        "backend": "rust-libp2p",
        "lan_fallback": false,
        "peer_id": body.peer_id,
    })
}

fn wire_pull_json(state: &SidecarState, body: WirePullRequest) -> Value {
    let notes = state
        .wire
        .lock()
        .expect("wire lock")
        .pull(&body.note_ids);
    json!({
        "status": "ok",
        "backend": "rust-libp2p",
        "lan_fallback": false,
        "peer_id": body.peer_id,
        "note_ids": body.note_ids,
        "notes": notes,
    })
}

fn wire_batch_export_json(state: &SidecarState) -> Value {
    let wire = state.wire.lock().expect("wire lock");
    let attachments = state.attachments.lock().expect("attachments lock");
    wire_batch::export_batch(&wire, &attachments)
}

fn wire_batch_import_json(state: &SidecarState, body: Value) -> Value {
    let imported = {
        let mut wire = state.wire.lock().expect("wire lock");
        let mut attachments = state.attachments.lock().expect("attachments lock");
        wire_batch::import_batch(&body, &mut wire, &mut attachments)
    };
    json!({
        "status": "ok",
        "backend": "rust-libp2p",
        "lan_fallback": false,
        "imported": imported,
    })
}

fn wire_attachment_push_json(state: &SidecarState, body: WireAttachmentPushRequest) -> Value {
    let bytes = STANDARD
        .decode(body.bytes_base64.as_bytes())
        .unwrap_or_default();
    let accepted = state
        .attachments
        .lock()
        .expect("attachments lock")
        .upsert(&body.note_id, &body.name, bytes);
    json!({
        "status": if accepted { "accepted" } else { "ignored" },
        "backend": "rust-libp2p",
        "lan_fallback": false,
        "peer_id": body.peer_id,
    })
}

fn wire_attachment_pull_json(
    state: &SidecarState,
    body: WireAttachmentPullRequest,
) -> Result<Value, String> {
    let blob = state
        .attachments
        .lock()
        .expect("attachments lock")
        .get(&body.note_id, &body.name)
        .map(|b| b.to_vec());
    let Some(bytes) = blob else {
        return Ok(json!({
            "status": "not_found",
            "backend": "rust-libp2p",
            "lan_fallback": false,
        }));
    };
    Ok(json!({
        "status": "ok",
        "backend": "rust-libp2p",
        "lan_fallback": false,
        "note_id": body.note_id,
        "name": body.name,
        "bytes_base64": STANDARD.encode(bytes),
    }))
}

pub async fn sync_json(state: &SidecarState, body: SyncRequest) -> Value {
    let peer_id = body.peer_id.clone().unwrap_or_else(|| {
        state
            .inner
            .lock()
            .expect("lock")
            .peer_id
            .clone()
            .unwrap_or_else(|| "sidecar".into())
    });

    let mut wire_imported = 0u32;
    let mut wire_pushed = 0u32;
    let mut import_via = "none";

    if let Some(ref remote_base) = body.remote_wire_base {
        match import_wire_from_http(remote_base, &state.wire, &state.attachments).await {
            Ok(count) => {
                wire_imported = count;
                import_via = "http_wire_base";
            }
            Err(err) => tracing::warn!("wire HTTP import from {remote_base} failed: {err}"),
        }
        match push_wire_batch_to_http(remote_base, &state.wire, &state.attachments).await {
            Ok(count) => wire_pushed = count,
            Err(err) => tracing::warn!("wire HTTP batch push to {remote_base} failed: {err}"),
        }
    } else if let Some(meshpad_peer) = body.peer_id.clone() {
        let p2p = {
            let runtime = state.inner.lock().expect("lock");
            runtime.p2p.clone()
        };
        if let Some(controller) = p2p.as_ref() {
            match controller.batch_sync_from_meshpad_peer(&meshpad_peer).await {
                Ok(stats) => {
                    wire_imported = stats.imported;
                    wire_pushed = stats.pushed;
                    import_via = "libp2p_batch";
                }
                Err(err) => {
                    tracing::warn!(
                        "libp2p batch sync from {meshpad_peer} failed, trying legacy pull/push: {err}"
                    );
                    if let Ok(count) = controller.pull_from_meshpad_peer(&meshpad_peer).await {
                        wire_imported = count;
                        import_via = "libp2p";
                    }
                    if let Ok(count) = controller.push_to_meshpad_peer(&meshpad_peer).await {
                        wire_pushed = count;
                    }
                }
            }
        }
    }

    let note_count = state.wire.lock().expect("wire lock").len() as u32;
    let _ = state.events.send(crate::events::SidecarEvent::sync_completed(
        peer_id.clone(),
        note_count,
    ));

    json!({
        "status": "delegated",
        "backend": "rust-libp2p",
        "lan_fallback": false,
        "wire_imported": wire_imported,
        "wire_pushed": wire_pushed,
        "import_via": import_via,
        "peer_id": peer_id,
    })
}
