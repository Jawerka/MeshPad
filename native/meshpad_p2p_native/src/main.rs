//! MeshPad libp2p sidecar binary — thin wrapper around [sidecar::run].

fn main() {
    tracing_subscriber::fmt()
        .with_env_filter("meshpad_p2p_native=info,tower_http=info")
        .init();

    let http_port = meshpad_p2p_native::sidecar::resolve_http_port();
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("tokio runtime");
    rt.block_on(async {
        if let Err(err) = meshpad_p2p_native::sidecar::run(http_port).await {
            eprintln!("sidecar exited: {err}");
            std::process::exit(1);
        }
    });
}
