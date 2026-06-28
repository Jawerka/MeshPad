import 'dart:convert';
import 'dart:io';

import 'http_libp2p_native_api.dart';
import 'sidecar_json_transport.dart';

/// Loopback HTTP JSON transport for the libp2p sidecar.
class HttpSidecarJsonTransport implements SidecarJsonTransport {
  HttpSidecarJsonTransport({
    required String baseUrl,
    HttpClient? httpClient,
  })  : _base = normalizeLibp2pSidecarBase(baseUrl),
        _http = httpClient ?? createLibp2pSidecarHttpClient();

  final Uri _base;
  final HttpClient _http;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    final value = await getValue(path);
    if (value is Map<String, dynamic>) return value;
    throw FormatException('expected JSON object from $path');
  }

  @override
  Future<dynamic> getValue(String path) async {
    final request = await _http.getUrl(_uri(path));
    final response = await request.close();
    return _decodeValue(path, response);
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final request = await _http.postUrl(_uri(path));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final response = await request.close();
    final decoded = await _decodeValue(path, response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('expected JSON object from $path');
  }

  Future<dynamic> _decodeValue(String path, HttpClientResponse response) async {
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('sidecar $path failed: ${response.statusCode} $text');
    }
    if (text.trim().isEmpty) return {};
    return jsonDecode(text);
  }

  Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return _base.resolve(normalized);
  }
}
