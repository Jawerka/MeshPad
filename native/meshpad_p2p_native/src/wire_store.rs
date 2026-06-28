//! In-memory [SYNC_WIRE.md] snapshots (PLAN 8.1).
use std::collections::HashMap;

use serde_json::{Value, json};

pub fn note_id_from_snapshot(snapshot: &Value) -> Option<String> {
    snapshot
        .get("meta")?
        .get("id")?
        .as_str()
        .map(str::to_string)
}

#[derive(Default)]
pub struct WireStore {
    notes: HashMap<String, Value>,
}

impl WireStore {
    pub fn len(&self) -> usize {
        self.notes.len()
    }

    pub fn upsert(&mut self, snapshot: Value) -> bool {
        let Some(id) = note_id_from_snapshot(&snapshot) else {
            return false;
        };
        self.notes.insert(id, snapshot);
        true
    }

    pub fn catalog_heads(&self) -> Vec<Value> {
        self.notes
            .iter()
            .map(|(id, snapshot)| {
                let meta = snapshot.get("meta").cloned().unwrap_or(json!({}));
                json!({
                    "id": id,
                    "updated_at": meta.get("updated_at").unwrap_or(&Value::Null),
                    "deleted": meta.get("deleted").unwrap_or(&json!(false)),
                })
            })
            .collect()
    }

    pub fn pull(&self, note_ids: &[String]) -> Vec<Value> {
        if note_ids.is_empty() {
            return self.notes.values().cloned().collect();
        }
        note_ids
            .iter()
            .filter_map(|id| self.notes.get(id).cloned())
            .collect()
    }

    pub fn all_snapshots(&self) -> Vec<Value> {
        self.notes.values().cloned().collect()
    }

    pub fn import_snapshots(&mut self, snapshots: impl IntoIterator<Item = Value>) -> u32 {
        let mut count = 0u32;
        for snapshot in snapshots {
            if self.upsert(snapshot) {
                count += 1;
            }
        }
        count
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn all_snapshots_returns_upserted_notes() {
        let mut store = WireStore::default();
        store.upsert(json!({ "meta": { "id": "a" }, "markdown": "one" }));
        store.upsert(json!({ "meta": { "id": "b" }, "markdown": "two" }));
        assert_eq!(store.all_snapshots().len(), 2);
    }
}
