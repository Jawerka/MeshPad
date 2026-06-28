//! SSE events consumed by [HttpLibp2pNativeApi](packages/meshpad_p2p).
use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
pub struct SidecarEvent {
    #[serde(rename = "type")]
    pub kind: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub peer_id: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub display_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub note_count: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lan_host: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub http_port: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tls_port: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub wire_base: Option<String>,
}

impl SidecarEvent {
    pub fn sync_completed(peer_id: String, note_count: u32) -> Self {
        Self {
            kind: "sync_completed".into(),
            peer_id: Some(peer_id),
            display_name: None,
            note_count: Some(note_count),
            message: None,
            lan_host: None,
            http_port: None,
            tls_port: None,
            wire_base: None,
        }
    }

    pub fn peer_discovered(
        peer_id: String,
        display_name: String,
        lan_host: Option<String>,
        http_port: Option<u16>,
        tls_port: Option<u16>,
        wire_base: Option<String>,
    ) -> Self {
        Self {
            kind: "peer_discovered".into(),
            peer_id: Some(peer_id),
            display_name: Some(display_name),
            note_count: None,
            message: None,
            lan_host,
            http_port,
            tls_port,
            wire_base,
        }
    }
}
