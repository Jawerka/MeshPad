import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'libp2p_native_api.dart';
import 'libp2p_sidecar_codec.dart';
import 'libp2p_sidecar_types.dart';
import 'ffi_direct_libp2p_native_api.dart';
import 'meshpad_ffi_bindings.dart';

/// Default localhost sidecar URL (PLAN §12 B.2).
const defaultLibp2pSidecarUrl = 'http://127.0.0.1:45839';

/// HTTP client for localhost sidecar (SSE + wire need >2 concurrent connections).
HttpClient createLibp2pSidecarHttpClient() {
  final client = HttpClient();
  client.maxConnectionsPerHost = 8;
  return client;
}

/// Normalizes sidecar base URL (trailing slash for [Uri.resolve]).
Uri normalizeLibp2pSidecarBase(String baseUrl) {
  final trimmed = baseUrl.trim();
  final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
  final uri = Uri.parse(withScheme);
  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}

/// HTTP/JSON bridge to the libp2p native sidecar process.
class HttpLibp2pNativeApi implements Libp2pNativeApi {
  HttpLibp2pNativeApi({
    required String baseUrl,
    HttpClient? httpClient,
    MeshpadFfiBindings? embeddedFfiOwner,
  })  : _base = normalizeLibp2pSidecarBase(baseUrl),
        _http = httpClient ?? createLibp2pSidecarHttpClient(),
        _embeddedFfiOwner = embeddedFfiOwner;

  final Uri _base;
  final HttpClient _http;
  final MeshpadFfiBindings? _embeddedFfiOwner;
  HttpClient? _eventsClient;
  StreamController<Libp2pNativeEvent>? _eventsController;
  StreamSubscription<Libp2pNativeEvent>? _sseSubscription;

  Uri get baseUri => _base;

  Future<bool> checkHealth() async {
    final health = await fetchHealth();
    return health?.ok ?? false;
  }

  Future<Libp2pSidecarHealth?> fetchHealth() async {
    try {
      final request = await _http.getUrl(_uri('/health'));
      final response =
          await request.close().timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return Libp2pSidecarHealth.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> start({
    required String peerId,
    required String displayName,
  }) async {
    _openEventsController();
    await _post('/v1/start', {
      'peer_id': peerId,
      'display_name': displayName,
    });
  }

  /// Closes the SSE connection so wire HTTP can use the host connection pool.
  Future<void> pauseEvents() async {
    await _sseSubscription?.cancel();
    _sseSubscription = null;
    _eventsClient?.close(force: true);
    _eventsClient = null;
  }

  Future<void> resumeEvents() async {
    if (_eventsController == null) return;
    await _ensureEventsSubscription();
  }

  @override
  Future<void> stop() async {
    await pauseEvents();
    final controller = _eventsController;
    _eventsController = null;
    if (controller != null && controller.hasListener) {
      await controller.close();
    }
    try {
      await _post('/v1/stop', const {}).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Sidecar may already be down.
    }
    _embeddedFfiOwner?.stopEmbedded();
  }

  @override
  Stream<Libp2pNativeEvent> get events {
    _openEventsController();
    return _eventsController!.stream;
  }

  void _openEventsController() {
    _eventsController ??= StreamController<Libp2pNativeEvent>.broadcast(
      onListen: () => unawaited(_ensureEventsSubscription()),
    );
  }

  @override
  Future<void> requestSync({String? peerId, String? remoteWireBase}) async {
    await requestSyncWithResult(peerId: peerId, remoteWireBase: remoteWireBase);
  }

  /// `POST /v1/sync` with parsed `{ wire_imported, wire_pushed, import_via }`.
  Future<Libp2pSidecarSyncResult> requestSyncWithResult({
    String? peerId,
    String? remoteWireBase,
  }) async {
    final json = await _postJson('/v1/sync', {
      if (peerId != null) 'peer_id': peerId,
      if (remoteWireBase != null && remoteWireBase.isNotEmpty)
        'remote_wire_base': remoteWireBase,
    });
    return Libp2pSidecarSyncResult.fromJson(json);
  }

  Future<void> _ensureEventsSubscription() async {
    if (_eventsController == null) return;
    if (_sseSubscription != null) return;

    _eventsClient ??= createLibp2pSidecarHttpClient();
    final request = await _eventsClient!.getUrl(_uri('/v1/events'));
    request.headers.set('Accept', 'text/event-stream');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('sidecar events failed: ${response.statusCode}');
    }

    final lineStream =
        response.transform(utf8.decoder).transform(const LineSplitter());
    _sseSubscription = parseLibp2pSidecarEventStream(lineStream).listen(
      _eventsController!.add,
      onError: _eventsController!.addError,
      onDone: () {
        _sseSubscription = null;
      },
    );
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    await _postJson(path, body);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final request = await _http.postUrl(_uri(path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('sidecar $path failed: ${response.statusCode} $text');
    }
    if (text.trim().isEmpty) return {};
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return _base.resolve(normalized);
  }
}

String? libp2pSidecarUrlFromEnvironment() {
  const fromDefine = String.fromEnvironment('MESHPAD_LIBP2P_SIDECAR_URL');
  if (fromDefine.isNotEmpty) return fromDefine;
  return Platform.environment['MESHPAD_LIBP2P_SIDECAR_URL'];
}

/// Direct in-process sidecar (PLAN 8.4, no loopback HTTP).
Future<Libp2pNativeApi?> _tryCreateDirectFfiApi() async {
  if (!shouldPreferLibp2pFfiDirect()) return null;
  final ffi = MeshpadFfiBindings.tryLoad();
  if (ffi == null || !ffi.startDirect()) return null;

  final api = FfiDirectLibp2pNativeApi(ffi);
  if ((await api.fetchHealth())?.ok ?? false) {
    return api;
  }
  ffi.stopDirect();
  return null;
}

/// Loopback HTTP sidecar in-process via Rust FFI (PLAN 8.4 fallback).
Future<Libp2pNativeApi?> _tryCreateEmbeddedHttpFfiApi() async {
  if (!shouldUseLibp2pFfiEmbed()) return null;
  final ffi = MeshpadFfiBindings.tryLoad();
  if (ffi == null) return null;

  const requestedPort = 45839;
  final port = ffi.startEmbedded(port: requestedPort);
  if (port == 0) return null;

  final api = HttpLibp2pNativeApi(
    baseUrl: 'http://127.0.0.1:$port',
    embeddedFfiOwner: ffi,
  );
  if (await api.checkHealth()) {
    return api;
  }
  ffi.stopEmbedded();
  return null;
}

/// Resolves sidecar API when URL is configured or sidecar responds on default port.
Future<Libp2pNativeApi?> createLibp2pNativeApi() async {
  final direct = await _tryCreateDirectFfiApi();
  if (direct != null) return direct;

  final embedded = await _tryCreateEmbeddedHttpFfiApi();
  if (embedded != null) return embedded;

  final configured = libp2pSidecarUrlFromEnvironment();
  if (configured != null && configured.isNotEmpty) {
    return HttpLibp2pNativeApi(baseUrl: configured);
  }

  final defaultApi = HttpLibp2pNativeApi(baseUrl: defaultLibp2pSidecarUrl);
  if (await defaultApi.checkHealth()) {
    return defaultApi;
  }
  return null;
}
