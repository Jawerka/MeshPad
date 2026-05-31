import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'libp2p_native_api.dart';
import 'libp2p_sidecar_codec.dart';

/// Default localhost sidecar URL (PLAN §12 B.2).
const defaultLibp2pSidecarUrl = 'http://127.0.0.1:45839';

/// HTTP/JSON bridge to the libp2p native sidecar process.
class HttpLibp2pNativeApi implements Libp2pNativeApi {
  HttpLibp2pNativeApi({required String baseUrl, HttpClient? httpClient})
      : _base = _normalizeBase(baseUrl),
        _http = httpClient ?? HttpClient();

  final Uri _base;
  final HttpClient _http;
  HttpClient? _eventsClient;
  StreamController<Libp2pNativeEvent>? _eventsController;
  StreamSubscription<Libp2pNativeEvent>? _sseSubscription;

  Uri get baseUri => _base;

  Future<bool> checkHealth() async {
    try {
      final request = await _http.getUrl(_uri('/health'));
      final response = await request.close().timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return false;
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['status'] == 'ok';
    } catch (_) {
      return false;
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
    await _ensureEventsSubscription();
  }

  @override
  Future<void> stop() async {
    await _sseSubscription?.cancel();
    _sseSubscription = null;
    _eventsClient?.close(force: true);
    _eventsClient = null;
    final controller = _eventsController;
    _eventsController = null;
    if (controller != null && controller.hasListener) {
      await controller.close();
    }
    try {
      await _post('/v1/stop', const {})
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Sidecar may already be down.
    }
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
  Future<void> requestSync({String? peerId}) async {
    await _post('/v1/sync', {
      if (peerId != null) 'peer_id': peerId,
    });
  }

  Future<void> _ensureEventsSubscription() async {
    if (_eventsController == null) return;
    if (_sseSubscription != null) return;

    _eventsClient ??= HttpClient();
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
    final request = await _http.postUrl(_uri(path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await response.transform(utf8.decoder).join();
      throw HttpException('sidecar $path failed: ${response.statusCode} $text');
    }
    await response.drain();
  }

  Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return _base.resolve(normalized);
  }

  static Uri _normalizeBase(String baseUrl) {
    final trimmed = baseUrl.trim();
    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.parse(withScheme);
    return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
  }
}

String? libp2pSidecarUrlFromEnvironment() {
  const fromDefine = String.fromEnvironment('MESHPAD_LIBP2P_SIDECAR_URL');
  if (fromDefine.isNotEmpty) return fromDefine;
  return Platform.environment['MESHPAD_LIBP2P_SIDECAR_URL'];
}

/// Resolves sidecar API when URL is configured or sidecar responds on default port.
Future<Libp2pNativeApi?> createLibp2pNativeApi() async {
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
