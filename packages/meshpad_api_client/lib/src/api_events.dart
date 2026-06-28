import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Feed change event from `GET /api/events` (SSE).
class MeshPadApiEvent {
  const MeshPadApiEvent({
    required this.type,
    this.noteId,
    this.id,
  });

  final String type;
  final String? noteId;

  /// Monotonic SSE event id (`id:` field) for [Last-Event-ID] reconnect.
  final int? id;

  factory MeshPadApiEvent.fromJson(Map<String, dynamic> json) {
    return MeshPadApiEvent(
      type: json['type'] as String? ?? 'feed_changed',
      noteId: json['note_id'] as String?,
    );
  }
}

/// Parses Server-Sent Events lines into [MeshPadApiEvent] payloads.
Stream<MeshPadApiEvent> parseSseEventStream(Stream<String> lineStream) async* {
  int? pendingId;
  await for (final line in lineStream) {
    if (line.startsWith('id:')) {
      pendingId = int.tryParse(line.substring(3).trim());
      continue;
    }
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trimLeft();
    if (payload.isEmpty) continue;
    final json = jsonDecode(payload) as Map<String, dynamic>;
    yield MeshPadApiEvent(
      id: pendingId,
      type: json['type'] as String? ?? 'feed_changed',
      noteId: json['note_id'] as String?,
    );
    pendingId = null;
  }
}

/// Reads an SSE body from a streaming HTTP response.
Stream<MeshPadApiEvent> meshPadEventsFromResponse(http.StreamedResponse response) {
  if (response.statusCode != 200) {
    return Stream.error(
      MeshPadApiException.fromResponse(response.statusCode, ''),
    );
  }

  final lineStream = response.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  return parseSseEventStream(lineStream);
}
