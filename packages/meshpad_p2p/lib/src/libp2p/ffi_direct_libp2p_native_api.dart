import 'dart:async';
import 'libp2p_native_api.dart';
import 'libp2p_sidecar_codec.dart';
import 'libp2p_sidecar_types.dart';
import 'meshpad_ffi_bindings.dart';
import 'sidecar_json_transport.dart';

/// In-process libp2p sidecar via Rust FFI (no loopback HTTP, PLAN 8.4).
class FfiDirectLibp2pNativeApi
    implements Libp2pNativeApi, SidecarJsonTransport {
  FfiDirectLibp2pNativeApi(this._ffi)
      : _transport = FfiSidecarJsonTransport(_ffi);

  final MeshpadFfiBindings _ffi;
  final FfiSidecarJsonTransport _transport;

  StreamController<Libp2pNativeEvent>? _eventsController;
  Timer? _pollTimer;
  bool _eventsPaused = false;

  SidecarJsonTransport get jsonTransport => _transport;

  @override
  Future<void> start({
    required String peerId,
    required String displayName,
  }) async {
    _openEventsController();
    await _transport.postJson('/v1/start', {
      'peer_id': peerId,
      'display_name': displayName,
    });
  }

  @override
  Future<void> stop() async {
    _stopPolling();
    final controller = _eventsController;
    _eventsController = null;
    if (controller != null && controller.hasListener) {
      await controller.close();
    }
    try {
      await _transport.postJson('/v1/stop', const {});
    } catch (_) {
      // Already stopped.
    }
    _ffi.stopDirect();
  }

  Future<void> pauseEvents() async {
    _eventsPaused = true;
  }

  Future<void> resumeEvents() async {
    _eventsPaused = false;
    _ensurePolling();
  }

  @override
  Stream<Libp2pNativeEvent> get events {
    _openEventsController();
    return _eventsController!.stream;
  }

  @override
  Future<void> requestSync({String? peerId, String? remoteWireBase}) async {
    await requestSyncWithResult(peerId: peerId, remoteWireBase: remoteWireBase);
  }

  Future<Libp2pSidecarSyncResult> requestSyncWithResult({
    String? peerId,
    String? remoteWireBase,
  }) async {
    final json = await _transport.postJson('/v1/sync', {
      if (peerId != null) 'peer_id': peerId,
      if (remoteWireBase != null && remoteWireBase.isNotEmpty)
        'remote_wire_base': remoteWireBase,
    });
    return Libp2pSidecarSyncResult.fromJson(json);
  }

  Future<Libp2pSidecarHealth?> fetchHealth() async {
    try {
      final json = await _transport.getJson('/health');
      return Libp2pSidecarHealth.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<dynamic> getValue(String path) => _transport.getValue(path);

  @override
  Future<Map<String, dynamic>> getJson(String path) => _transport.getJson(path);

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) =>
      _transport.postJson(path, body);

  void _openEventsController() {
    _eventsController ??= StreamController<Libp2pNativeEvent>.broadcast(
      onListen: _ensurePolling,
      onCancel: () {
        if (!(_eventsController?.hasListener ?? false)) {
          _stopPolling();
        }
      },
    );
  }

  void _ensurePolling() {
    if (_eventsPaused || _eventsController == null) return;
    _pollTimer ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
      _drainEvents();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _drainEvents() {
    final controller = _eventsController;
    if (controller == null || controller.isClosed || _eventsPaused) return;
    while (true) {
      final json = _ffi.pollEventJson();
      if (json == null) break;
      try {
        controller.add(libp2pSidecarEventFromJson(json));
      } catch (_) {
        // Ignore malformed events.
      }
    }
  }
}

/// [SidecarJsonTransport] backed by `meshpad_ffi_request`.
class FfiSidecarJsonTransport implements SidecarJsonTransport {
  FfiSidecarJsonTransport(this._ffi);

  final MeshpadFfiBindings _ffi;

  @override
  Future<dynamic> getValue(String path) {
    return _ffi.requestValue(path: path, post: false);
  }

  @override
  Future<Map<String, dynamic>> getJson(String path) {
    return _ffi.requestJson(path: path, post: false);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) {
    return _ffi.requestJson(path: path, post: true, body: body);
  }
}
