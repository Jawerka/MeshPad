import 'note_tags.dart';

/// Metadata for a note directory (`meta.json` schema v1).
class NoteMeta {
  const NoteMeta({
    required this.schemaVersion,
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.author,
    this.deleted = false,
    this.deletedAt,
    this.attachments = const [],
    this.tags = const [],
    this.revision = 0,
    this.vectorClock = const {},
  });

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String author;
  final bool deleted;
  final DateTime? deletedAt;
  final List<AttachmentMeta> attachments;
  final List<String> tags;

  /// Monotonic local edit counter (PLAN §11.3.2).
  final int revision;

  /// Optional per-device counters for future merge (PLAN §11.3.3).
  final Map<String, int> vectorClock;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'id': id,
        'title': title,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'author': author,
        'deleted': deleted,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        if (tags.isNotEmpty) 'tags': normalizeTags(tags),
        if (revision > 0) 'revision': revision,
        if (vectorClock.isNotEmpty) 'vector_clock': vectorClock,
      };

  factory NoteMeta.fromJson(Map<String, dynamic> json) {
    return NoteMeta(
      schemaVersion: json['schema_version'] as int? ?? 1,
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      author: json['author'] as String? ?? '',
      deleted: json['deleted'] as bool? ?? false,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String).toUtc()
          : null,
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((e) => AttachmentMeta.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: normalizeTags(
        (json['tags'] as List<dynamic>? ?? []).map((e) => '$e'),
      ),
      revision: json['revision'] as int? ?? 0,
      vectorClock: _parseVectorClock(json['vector_clock']),
    );
  }

  NoteMeta copyWith({
    String? title,
    DateTime? updatedAt,
    bool? deleted,
    DateTime? deletedAt,
    List<AttachmentMeta>? attachments,
    List<String>? tags,
    int? revision,
    Map<String, int>? vectorClock,
    bool clearDeletedAt = false,
  }) {
    return NoteMeta(
      schemaVersion: schemaVersion,
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      author: author,
      deleted: deleted ?? this.deleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      attachments: attachments ?? this.attachments,
      tags: tags ?? this.tags,
      revision: revision ?? this.revision,
      vectorClock: vectorClock ?? this.vectorClock,
    );
  }
}

Map<String, int> _parseVectorClock(Object? raw) {
  if (raw is! Map) return const {};
  return raw.map(
    (key, value) =>
        MapEntry('$key', value is int ? value : int.tryParse('$value') ?? 0),
  );
}

class AttachmentMeta {
  const AttachmentMeta({
    required this.name,
    required this.size,
    this.mime,
    this.sha256,
  });

  final String name;
  final int size;
  final String? mime;
  final String? sha256;

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        if (mime != null) 'mime': mime,
        if (sha256 != null) 'sha256': sha256,
      };

  factory AttachmentMeta.fromJson(Map<String, dynamic> json) => AttachmentMeta(
        name: json['name'] as String,
        size: json['size'] as int,
        mime: json['mime'] as String?,
        sha256: json['sha256'] as String?,
      );
}
