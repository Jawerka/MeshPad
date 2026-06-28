import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:meshpad_core/meshpad_core.dart';

const _gzipEncoder = GZipEncoder();
const _gzipDecoder = GZipDecoder();

/// Minimum UTF-8 JSON size before LAN catalog responses use gzip (PLAN §11.5.5).
const lanCatalogGzipMinBytes = 256;

const lanCatalogGzipEncoding = 'gzip';

/// Whether [acceptEncoding] from the client allows gzip (e.g. `gzip, deflate`).
bool lanCatalogAcceptsGzip(String? acceptEncoding) {
  if (acceptEncoding == null || acceptEncoding.isEmpty) return false;
  return acceptEncoding
      .toLowerCase()
      .split(',')
      .map((part) => part.trim().split(';').first)
      .contains(lanCatalogGzipEncoding);
}

/// Encodes [catalog] to JSON bytes, optionally gzip-compressed.
({List<int> bytes, bool gzipped}) encodeLanCatalogBody(
  List<NoteHead> catalog, {
  required bool useGzip,
}) {
  final jsonBytes = utf8.encode(
    jsonEncode([for (final head in catalog) head.toJson()]),
  );
  if (!useGzip || jsonBytes.length < lanCatalogGzipMinBytes) {
    return (bytes: jsonBytes, gzipped: false);
  }
  return (bytes: _gzipEncoder.encode(jsonBytes), gzipped: true);
}

/// Decodes catalog JSON whether or not the body was gzip-compressed.
List<NoteHead> decodeLanCatalogBody(List<int> bodyBytes, {bool gzipped = false}) {
  final jsonBytes = gzipped ? _gzipDecoder.decodeBytes(bodyBytes) : bodyBytes;
  final decoded = jsonDecode(utf8.decode(jsonBytes)) as List<dynamic>;
  return noteHeadsFromJsonList(decoded);
}
