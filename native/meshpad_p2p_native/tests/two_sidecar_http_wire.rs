//! PLAN 8.2–8.3: two `meshpad_p2p_sidecar` processes replicate wire notes via HTTP.
//!
//! Run after `cargo build` (CI `rust-sidecar` job). Skips quietly if the binary is missing.

use std::{
    net::TcpListener,
    path::PathBuf,
    process::{Child, Command, Stdio},
    time::Duration,
};

use serde_json::json;

fn sidecar_bin() -> Option<PathBuf> {
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").ok()?;
    let profile = std::env::var("PROFILE").unwrap_or_else(|_| "debug".into());
    let mut bin = PathBuf::from(manifest_dir);
    bin.push("target");
    bin.push(profile);
    bin.push("meshpad_p2p_sidecar");
    #[cfg(windows)]
    {
        bin.set_extension("exe");
    }
    if bin.exists() {
        Some(bin)
    } else {
        None
    }
}

fn pick_port() -> u16 {
    TcpListener::bind("127.0.0.1:0")
        .expect("bind ephemeral port")
        .local_addr()
        .expect("local_addr")
        .port()
}

struct SidecarProcess(Child);

impl Drop for SidecarProcess {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

fn spawn_sidecar(bin: &PathBuf, port: u16) -> SidecarProcess {
    let child = Command::new(bin)
        .arg("--port")
        .arg(port.to_string())
        .env("MESHPAD_LIBP2P_SIDECAR_PORT", port.to_string())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .expect("spawn sidecar");
    SidecarProcess(child)
}

async fn wait_health(client: &reqwest::Client, port: u16) {
    let url = format!("http://127.0.0.1:{port}/health");
    for _ in 0..80 {
        if let Ok(resp) = client.get(&url).send().await {
            if resp.status().is_success() {
                if let Ok(body) = resp.json::<serde_json::Value>().await {
                    if body.get("status").and_then(|v| v.as_str()) == Some("ok") {
                        return;
                    }
                }
            }
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
    panic!("sidecar on port {port} did not become healthy");
}

#[tokio::test]
async fn two_sidecars_replicate_via_remote_wire_base() {
    let Some(bin) = sidecar_bin() else {
        eprintln!("skip: meshpad_p2p_sidecar binary not found (run cargo build)");
        return;
    };

    let port_a = pick_port();
    let port_b = pick_port();
    let _proc_a = spawn_sidecar(&bin, port_a);
    let _proc_b = spawn_sidecar(&bin, port_b);

    let client = reqwest::Client::new();
    wait_health(&client, port_a).await;
    wait_health(&client, port_b).await;

    let health_a: serde_json::Value = client
        .get(format!("http://127.0.0.1:{port_a}/health"))
        .send()
        .await
        .expect("health a")
        .json()
        .await
        .expect("health a json");
    assert_eq!(
        health_a.get("backend").and_then(|v| v.as_str()),
        Some("rust-libp2p")
    );

    let snapshot = json!({
        "meta": {
            "schema_version": 2,
            "id": "rust-e2e-note",
            "title": "From B",
            "author": "peer-b",
            "created_at": "2026-06-01T08:00:00.000Z",
            "updated_at": "2026-06-01T09:00:00.000Z",
            "deleted": false
        },
        "markdown": "# rust e2e"
    });

    client
        .post(format!("http://127.0.0.1:{port_b}/v1/wire/push"))
        .json(&json!({ "snapshot": snapshot }))
        .send()
        .await
        .expect("push b")
        .error_for_status()
        .expect("push b status");

    client
        .post(format!("http://127.0.0.1:{port_a}/v1/start"))
        .json(&json!({
            "peer_id": "peer-a",
            "display_name": "A",
        }))
        .send()
        .await
        .expect("start a")
        .error_for_status()
        .expect("start a status");

    let sync: serde_json::Value = client
        .post(format!("http://127.0.0.1:{port_a}/v1/sync"))
        .json(&json!({
            "peer_id": "peer-b",
            "remote_wire_base": format!("http://127.0.0.1:{port_b}/"),
        }))
        .send()
        .await
        .expect("sync a")
        .error_for_status()
        .expect("sync a status")
        .json()
        .await
        .expect("sync json");

    assert_eq!(
        sync.get("import_via").and_then(|v| v.as_str()),
        Some("http_wire_base")
    );
    assert!(sync.get("wire_imported").and_then(|v| v.as_u64()).unwrap_or(0) >= 1);
    assert!(
        sync.get("wire_pushed").and_then(|v| v.as_u64()).unwrap_or(0) >= 1,
        "batch push should replicate local wire store back to B"
    );

    let catalog: Vec<serde_json::Value> = client
        .get(format!("http://127.0.0.1:{port_a}/v1/wire/catalog"))
        .send()
        .await
        .expect("catalog a")
        .error_for_status()
        .expect("catalog a status")
        .json()
        .await
        .expect("catalog json");
    assert_eq!(catalog.len(), 1);
    assert_eq!(
        catalog[0].get("id").and_then(|v| v.as_str()),
        Some("rust-e2e-note")
    );
}
