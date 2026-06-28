//! C ABI for embedding the sidecar in-process (PLAN §11.8.4).
//!
//! - [meshpad_ffi_start_embedded]: loopback HTTP (legacy)
//! - [meshpad_ffi_start_direct]: JSON dispatch without TCP

use std::{
    ffi::{CStr, CString},
    sync::{
        Mutex,
        atomic::{AtomicU16, Ordering},
    },
    thread::JoinHandle,
};

use crate::{sidecar, sidecar_api::{self, HttpMethod}};

static EMBEDDED_PORT: AtomicU16 = AtomicU16::new(0);

struct EmbeddedServer {
    shutdown_tx: tokio::sync::oneshot::Sender<()>,
    thread: JoinHandle<()>,
}

static EMBEDDED: Mutex<Option<EmbeddedServer>> = Mutex::new(None);

fn init_tracing_once() {
    let _ = tracing_subscriber::fmt()
        .with_env_filter("meshpad_p2p_native=info")
        .try_init();
}

/// Returns the listen port after [meshpad_ffi_start_embedded], or `0` when stopped.
#[no_mangle]
pub extern "C" fn meshpad_ffi_embedded_port() -> u16 {
    EMBEDDED_PORT.load(Ordering::SeqCst)
}

/// Starts the sidecar on `127.0.0.1`. `requested_port == 0` picks an ephemeral port.
/// Returns the bound port, or `0` on failure / if already running.
#[no_mangle]
pub extern "C" fn meshpad_ffi_start_embedded(requested_port: u16) -> u16 {
    init_tracing_once();

    let mut guard = EMBEDDED.lock().expect("embedded lock");
    if guard.is_some() {
        return EMBEDDED_PORT.load(Ordering::SeqCst);
    }

    let (shutdown_tx, shutdown_rx) = tokio::sync::oneshot::channel::<()>();
    let port_slot = std::sync::Arc::new(AtomicU16::new(0));
    let port_for_thread = port_slot.clone();

    let thread = std::thread::spawn(move || {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .expect("ffi tokio runtime");
        rt.block_on(async {
            let listener = match sidecar::bind_listener(requested_port).await {
                Ok(l) => l,
                Err(_) => return,
            };
            let port = listener.local_addr().map(|a| a.port()).unwrap_or(0);
            port_for_thread.store(port, Ordering::SeqCst);
            EMBEDDED_PORT.store(port, Ordering::SeqCst);

            let app = sidecar::build_router(port);
            let _ = axum::serve(listener, app)
                .with_graceful_shutdown(async {
                    let _ = shutdown_rx.await;
                })
                .await;
            EMBEDDED_PORT.store(0, Ordering::SeqCst);
        });
    });

    for _ in 0..200 {
        let port = port_slot.load(Ordering::SeqCst);
        if port != 0 {
            *guard = Some(EmbeddedServer { shutdown_tx, thread });
            return port;
        }
        std::thread::sleep(std::time::Duration::from_millis(10));
    }

    let _ = shutdown_tx.send(());
    let _ = thread.join();
    0
}

/// Stops the embedded server started by [meshpad_ffi_start_embedded]. Returns `0` on success.
#[no_mangle]
pub extern "C" fn meshpad_ffi_stop_embedded() -> i32 {
    let mut guard = EMBEDDED.lock().expect("embedded lock");
    let Some(server) = guard.take() else {
        EMBEDDED_PORT.store(0, Ordering::SeqCst);
        return 0;
    };

    let _ = server.shutdown_tx.send(());
    let _ = server.thread.join();
    EMBEDDED_PORT.store(0, Ordering::SeqCst);
    0
}

/// Library version string (static, UTF-8).
#[no_mangle]
pub extern "C" fn meshpad_ffi_version() -> *const std::os::raw::c_char {
    static VERSION: &[u8] = b"meshpad_p2p_native/0.1.0\0";
    VERSION.as_ptr() as *const std::os::raw::c_char
}

struct DirectRuntime {
    rt: tokio::runtime::Runtime,
    state: sidecar::SidecarState,
    events_rx: tokio::sync::broadcast::Receiver<crate::events::SidecarEvent>,
}

static DIRECT: Mutex<Option<DirectRuntime>> = Mutex::new(None);

fn json_ptr(value: serde_json::Value) -> *mut std::os::raw::c_char {
    let text = value.to_string();
    CString::new(text).map(|c| c.into_raw()).unwrap_or(std::ptr::null_mut())
}

fn error_ptr(message: impl Into<String>) -> *mut std::os::raw::c_char {
    json_ptr(serde_json::json!({ "error": message.into() }))
}

/// Frees a string returned by [meshpad_ffi_request] or [meshpad_ffi_poll_event].
#[no_mangle]
pub unsafe extern "C" fn meshpad_ffi_free_string(ptr: *mut std::os::raw::c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}

/// Starts in-process sidecar without loopback HTTP. Returns `1` on success.
#[no_mangle]
pub extern "C" fn meshpad_ffi_start_direct() -> u8 {
    init_tracing_once();
    let mut guard = DIRECT.lock().expect("direct lock");
    if guard.is_some() {
        return 1;
    }
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("direct tokio runtime");
    let state = sidecar::new_sidecar_state(0);
    let events_rx = state.events.subscribe();
    *guard = Some(DirectRuntime { rt, state, events_rx });
    1
}

/// Stops the direct runtime started by [meshpad_ffi_start_direct].
#[no_mangle]
pub extern "C" fn meshpad_ffi_stop_direct() -> i32 {
    let mut guard = DIRECT.lock().expect("direct lock");
    let Some(runtime) = guard.take() else {
        return 0;
    };
    let state = runtime.state.clone();
    runtime.rt.block_on(sidecar_api::stop_json(&state));
    0
}

/// `method`: `0` = GET, `1` = POST. `body` may be null. Returns owned JSON (free with [meshpad_ffi_free_string]).
#[no_mangle]
pub unsafe extern "C" fn meshpad_ffi_request(
    method: u8,
    path: *const std::os::raw::c_char,
    body: *const std::os::raw::c_char,
) -> *mut std::os::raw::c_char {
    let guard = DIRECT.lock().expect("direct lock");
    let Some(runtime) = guard.as_ref() else {
        return error_ptr("direct runtime not started");
    };

    let path = match CStr::from_ptr(path).to_str() {
        Ok(p) => p,
        Err(_) => return error_ptr("invalid path utf-8"),
    };

    let body_value = if body.is_null() {
        None
    } else {
        match CStr::from_ptr(body).to_str() {
            Ok(text) if text.trim().is_empty() => None,
            Ok(text) => match serde_json::from_str(text) {
                Ok(v) => Some(v),
                Err(err) => return error_ptr(err.to_string()),
            },
            Err(_) => return error_ptr("invalid body utf-8"),
        }
    };

    let http_method = match method {
        0 => HttpMethod::Get,
        1 => HttpMethod::Post,
        _ => return error_ptr("method must be 0 (GET) or 1 (POST)"),
    };

    let state = runtime.state.clone();
    match runtime
        .rt
        .block_on(sidecar_api::dispatch_json(&state, http_method, path, body_value))
    {
        Ok(value) => json_ptr(value),
        Err(err) => error_ptr(err),
    }
}

/// Returns the next sidecar event as JSON, or null when the queue is empty.
#[no_mangle]
pub extern "C" fn meshpad_ffi_poll_event() -> *mut std::os::raw::c_char {
    let mut guard = DIRECT.lock().expect("direct lock");
    let Some(runtime) = guard.as_mut() else {
        return std::ptr::null_mut();
    };
    match runtime.events_rx.try_recv() {
        Ok(event) => json_ptr(
            serde_json::to_value(event).unwrap_or(serde_json::json!({ "error": "event encode" })),
        ),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Returns `0` when [ptr] is a valid version string from [meshpad_ffi_version].
#[no_mangle]
pub unsafe extern "C" fn meshpad_ffi_version_check(ptr: *const std::os::raw::c_char) -> i32 {
    if ptr.is_null() {
        return -1;
    }
    match CStr::from_ptr(ptr).to_str() {
        Ok(s) if s.starts_with("meshpad_p2p_native/") => 0,
        _ => -1,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_string_is_valid_cstr() {
        let ptr = meshpad_ffi_version();
        assert_eq!(unsafe { meshpad_ffi_version_check(ptr) }, 0);
    }

    #[test]
    fn embedded_start_stop_on_ephemeral_port() {
        let port = meshpad_ffi_start_embedded(0);
        assert!(port > 0, "expected ephemeral bind, got {port}");
        assert_eq!(meshpad_ffi_embedded_port(), port);
        assert_eq!(meshpad_ffi_stop_embedded(), 0);
        assert_eq!(meshpad_ffi_embedded_port(), 0);
    }

    #[test]
    fn direct_health_without_http() {
        assert_eq!(meshpad_ffi_start_direct(), 1);
        let path = CString::new("/health").expect("path");
        let ptr = unsafe { meshpad_ffi_request(0, path.as_ptr(), std::ptr::null()) };
        assert!(!ptr.is_null());
        let text = unsafe { CStr::from_ptr(ptr) }.to_str().expect("utf8");
        assert!(text.contains("rust-libp2p"));
        unsafe { meshpad_ffi_free_string(ptr) };
        assert_eq!(meshpad_ffi_stop_direct(), 0);
    }
}
