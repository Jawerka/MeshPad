import 'dart:convert';

import 'package:meshpad_core/meshpad_core.dart';

Note noteFromApiJson(Map<String, dynamic> json) {
  return Note(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    markdown: json['markdown'] as String? ?? json['preview'] as String? ?? '',
    author: json['author'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    deleted: json['deleted'] as bool? ?? false,
    deletedAt: json['deleted_at'] == null
        ? null
        : DateTime.parse(json['deleted_at'] as String),
    attachments: [
      for (final raw in json['attachments'] as List? ?? const [])
        attachmentFromApiJson(raw as Map<String, dynamic>),
    ],
    tags: tagsFromApiJson(json['tags']),
  );
}

List<String> tagsFromApiJson(dynamic raw) {
  if (raw == null) return const [];
  if (raw is! List) return const [];
  return normalizeTags(raw.map((e) => '$e'));
}

AttachmentMeta attachmentFromApiJson(Map<String, dynamic> json) {
  return AttachmentMeta(
    name: json['name'] as String,
    size: json['size'] as int? ?? 0,
    mime: json['mime'] as String?,
    sha256: json['sha256'] as String?,
  );
}

List<Note> notesFromApiList(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw const FormatException('Expected JSON array of notes');
  }
  return [
    for (final item in decoded)
      noteFromApiJson(item as Map<String, dynamic>),
  ];
}

Note noteFromApiBody(String body) => noteFromApiJson(
      jsonDecode(body) as Map<String, dynamic>,
    );

List<NoteSearchHit> searchHitsFromApiList(String body) {
  final decoded = jsonDecode(body) as List;
  return [
    for (final item in decoded)
      NoteSearchHit(
        note: noteFromApiJson(item['note'] as Map<String, dynamic>),
        snippet: item['snippet'] as String? ?? '',
      ),
  ];
}
