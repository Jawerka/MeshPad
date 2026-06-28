//! Wire sync batch envelope ([SYNC_WIRE.md], PLAN 8.1).
use base64::{Engine, engine::general_purpose::STANDARD};
use serde_json::{Value, json};

use crate::wire_attachment_store::WireAttachmentStore;
use crate::wire_store::WireStore;

pub fn import_batch(
    batch: &Value,
    wire: &mut WireStore,
    attachments: &mut WireAttachmentStore,
) -> u32 {
    let version = batch.get("version").and_then(|v| v.as_u64()).unwrap_or(0);
    if version != 1 {
        return 0;
    }
    let mut count = 0u32;
    if let Some(notes) = batch.get("notes").and_then(|n| n.as_array()) {
        for note in notes {
            if wire.upsert(note.clone()) {
                count += 1;
            }
        }
    }
    if let Some(atts) = batch.get("attachments").and_then(|a| a.as_array()) {
        for att in atts {
            let Some(obj) = att.as_object() else {
                continue;
            };
            let note_id = obj.get("note_id").and_then(|v| v.as_str()).unwrap_or("");
            let name = obj.get("name").and_then(|v| v.as_str()).unwrap_or("");
            let b64 = obj
                .get("bytes_base64")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            if note_id.is_empty() || name.is_empty() || b64.is_empty() {
                continue;
            }
            if let Ok(bytes) = STANDARD.decode(b64) {
                if attachments.upsert(note_id, name, bytes) {
                    count += 1;
                }
            }
        }
    }
    count
}

pub fn export_batch(wire: &WireStore, attachments: &WireAttachmentStore) -> Value {
    let notes = wire.all_snapshots();
    let catalog = wire.catalog_heads();
    let att_json: Vec<Value> = attachments
        .iter()
        .map(|(note_id, name, bytes)| {
            json!({
                "note_id": note_id,
                "name": name,
                "bytes_base64": STANDARD.encode(bytes),
            })
        })
        .collect();
    json!({
        "version": 1,
        "catalog": catalog,
        "notes": notes,
        "attachments": att_json,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn batch_round_trip() {
        let mut wire = WireStore::default();
        let mut attachments = WireAttachmentStore::default();
        wire.upsert(json!({ "meta": { "id": "n1" }, "markdown": "x" }));
        attachments.upsert("n1", "f.png", vec![9, 9]);

        let exported = export_batch(&wire, &attachments);
        let mut wire2 = WireStore::default();
        let mut att2 = WireAttachmentStore::default();
        let n = import_batch(&exported, &mut wire2, &mut att2);
        assert!(n >= 2);
        assert_eq!(wire2.len(), 1);
        assert!(att2.get("n1", "f.png").is_some());
    }
}
