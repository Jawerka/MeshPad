//! MeshPad wire messages over libp2p request-response ([SYNC_WIRE.md]).
use serde::{Deserialize, Serialize};
use serde_json::Value;

pub const WIRE_PROTOCOL: &str = "/meshpad/wire/1.0.0";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum WireRequest {
    Hello {
        peer_id: String,
        display_name: String,
    },
    GetCatalog,
    Pull {
        note_ids: Vec<String>,
    },
    Push {
        snapshot: Value,
    },
    /// Export full wire batch envelope ([SYNC_WIRE.md] § wire batch).
    GetBatch,
    /// Import batch envelope on the peer.
    PushBatch {
        batch: Value,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum WireResponse {
    HelloAck,
    Catalog {
        heads: Vec<Value>,
    },
    Pull {
        notes: Vec<Value>,
    },
    PushAck,
    Batch {
        batch: Value,
    },
    BatchAck {
        imported: u32,
    },
    Error {
        message: String,
    },
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn wire_request_round_trip() {
        let req = WireRequest::Pull {
            note_ids: vec!["n1".into()],
        };
        let bytes = serde_json::to_vec(&req).unwrap();
        let back: WireRequest = serde_json::from_slice(&bytes).unwrap();
        assert!(matches!(back, WireRequest::Pull { .. }));
    }

    #[test]
    fn batch_request_round_trip() {
        let req = WireRequest::PushBatch {
            batch: json!({ "version": 1, "notes": [] }),
        };
        let text = serde_json::to_string(&req).unwrap();
        assert!(text.contains("push_batch"));
    }

    #[test]
    fn catalog_response_json() {
        let resp = WireResponse::Catalog {
            heads: vec![json!({"id": "a"})],
        };
        let text = serde_json::to_string(&resp).unwrap();
        assert!(text.contains("catalog"));
    }
}
