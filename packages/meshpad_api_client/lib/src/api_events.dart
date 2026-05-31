import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Feed change event from `GET /api/events` (SSE).
class MeshPadApiEvent {
  const MeshPadApiEvent({required this.type, this.noteId});

  final String type;
  final String? noteId;

  factory MeshPadApiEvent.fromJson(Map<String, dynamic> json) {
    return MeshPadApiEvent(
      type: json['type'] as String? ?? 'feed_changed',
      noteId: json['note_id'] as String?,
    );
  }
}

/// Parses Server-Sent Events lines into [MeshPadApiEvent] payloads.
Stream<MeshPadApiEvent> parseSseEventStream(Stream<String> lineStream) async* {
  await for (final line in lineStream) {
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trimLeft();
    if (payload.isEmpty) continue;
    yield MeshPadApiEvent.fromJson(
      jsonDecode(payload) as Map<String, dynamic>,
    );
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
