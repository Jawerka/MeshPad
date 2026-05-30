import 'note_meta.dart';

/// Domain note: metadata + markdown body.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.markdown,
    required this.createdAt,
    required this.updatedAt,
    required this.author,
    this.deleted = false,
    this.deletedAt,
    this.attachments = const [],
  });

  final String id;
  final String title;
  final String markdown;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String author;
  final bool deleted;
  final DateTime? deletedAt;
  final List<AttachmentMeta> attachments;

  factory Note.fromMeta({
    required NoteMeta meta,
    required String markdown,
  }) {
    return Note(
      id: meta.id,
      title: meta.title,
      markdown: markdown,
      createdAt: meta.createdAt,
      updatedAt: meta.updatedAt,
      author: meta.author,
      deleted: meta.deleted,
      deletedAt: meta.deletedAt,
      attachments: meta.attachments,
    );
  }

  NoteMeta toMeta() => NoteMeta(
        schemaVersion: NoteMeta.currentSchemaVersion,
        id: id,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt,
        author: author,
        deleted: deleted,
        deletedAt: deletedAt,
        attachments: attachments,
      );

  Note copyWith({
    String? title,
    String? markdown,
    DateTime? updatedAt,
    bool? deleted,
    DateTime? deletedAt,
    List<AttachmentMeta>? attachments,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      author: author,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      attachments: attachments ?? this.attachments,
    );
  }
}

enum NoteSort { createdAt, updatedAt }
