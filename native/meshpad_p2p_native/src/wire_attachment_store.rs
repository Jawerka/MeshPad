//! In-memory attachment blobs for sidecar wire API (PLAN 8.1).
use std::collections::HashMap;

pub const MAX_ATTACHMENT_BYTES: usize = 16 * 1024 * 1024;

fn attachment_key(note_id: &str, name: &str) -> String {
    format!("{note_id}\0{name}")
}

#[derive(Default)]
pub struct WireAttachmentStore {
    blobs: HashMap<String, Vec<u8>>,
}

impl WireAttachmentStore {
    pub fn len(&self) -> usize {
        self.blobs.len()
    }

    pub fn upsert(&mut self, note_id: &str, name: &str, bytes: Vec<u8>) -> bool {
        if note_id.is_empty() || name.is_empty() {
            return false;
        }
        if bytes.len() > MAX_ATTACHMENT_BYTES {
            return false;
        }
        self.blobs.insert(attachment_key(note_id, name), bytes);
        true
    }

    pub fn get(&self, note_id: &str, name: &str) -> Option<&[u8]> {
        self.blobs
            .get(&attachment_key(note_id, name))
            .map(|v| v.as_slice())
    }

    pub fn iter(&self) -> impl Iterator<Item = (&str, &str, &[u8])> + '_ {
        self.blobs.iter().filter_map(|(key, bytes)| {
            let (note_id, name) = key.split_once('\0')?;
            Some((note_id, name, bytes.as_slice()))
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn upsert_and_get_round_trip() {
        let mut store = WireAttachmentStore::default();
        assert!(store.upsert("n1", "a.jpg", vec![1, 2, 3]));
        assert_eq!(store.get("n1", "a.jpg"), Some([1u8, 2, 3].as_slice()));
        assert_eq!(store.get("n1", "b.jpg"), None);
    }
}
