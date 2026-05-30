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
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String author;
  final bool deleted;
  final DateTime? deletedAt;
  final List<AttachmentMeta> attachments;

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
    );
  }
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
