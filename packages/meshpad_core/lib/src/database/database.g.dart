// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $NotesTable extends Notes with TableInfo<$NotesTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _previewSnippetMeta =
      const VerificationMeta('previewSnippet');
  @override
  late final GeneratedColumn<String> previewSnippet = GeneratedColumn<String>(
      'preview_snippet', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _markdownMeta =
      const VerificationMeta('markdown');
  @override
  late final GeneratedColumn<String> markdown = GeneratedColumn<String>(
      'markdown', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _fsMetaModifiedAtMeta =
      const VerificationMeta('fsMetaModifiedAt');
  @override
  late final GeneratedColumn<DateTime> fsMetaModifiedAt =
      GeneratedColumn<DateTime>('fs_meta_modified_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _fsMarkdownModifiedAtMeta =
      const VerificationMeta('fsMarkdownModifiedAt');
  @override
  late final GeneratedColumn<DateTime> fsMarkdownModifiedAt =
      GeneratedColumn<DateTime>('fs_markdown_modified_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _fsAttachmentsModifiedAtMeta =
      const VerificationMeta('fsAttachmentsModifiedAt');
  @override
  late final GeneratedColumn<DateTime> fsAttachmentsModifiedAt =
      GeneratedColumn<DateTime>('fs_attachments_modified_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        author,
        createdAt,
        updatedAt,
        deleted,
        deletedAt,
        previewSnippet,
        markdown,
        tags,
        fsMetaModifiedAt,
        fsMarkdownModifiedAt,
        fsAttachmentsModifiedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(Insertable<NoteRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('preview_snippet')) {
      context.handle(
          _previewSnippetMeta,
          previewSnippet.isAcceptableOrUnknown(
              data['preview_snippet']!, _previewSnippetMeta));
    }
    if (data.containsKey('markdown')) {
      context.handle(_markdownMeta,
          markdown.isAcceptableOrUnknown(data['markdown']!, _markdownMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('fs_meta_modified_at')) {
      context.handle(
          _fsMetaModifiedAtMeta,
          fsMetaModifiedAt.isAcceptableOrUnknown(
              data['fs_meta_modified_at']!, _fsMetaModifiedAtMeta));
    }
    if (data.containsKey('fs_markdown_modified_at')) {
      context.handle(
          _fsMarkdownModifiedAtMeta,
          fsMarkdownModifiedAt.isAcceptableOrUnknown(
              data['fs_markdown_modified_at']!, _fsMarkdownModifiedAtMeta));
    }
    if (data.containsKey('fs_attachments_modified_at')) {
      context.handle(
          _fsAttachmentsModifiedAtMeta,
          fsAttachmentsModifiedAt.isAcceptableOrUnknown(
              data['fs_attachments_modified_at']!,
              _fsAttachmentsModifiedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      previewSnippet: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preview_snippet'])!,
      markdown: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}markdown'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      fsMetaModifiedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}fs_meta_modified_at']),
      fsMarkdownModifiedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}fs_markdown_modified_at']),
      fsAttachmentsModifiedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}fs_attachments_modified_at']),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  final String id;
  final String title;
  final String author;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  final DateTime? deletedAt;
  final String previewSnippet;
  final String markdown;
  final String tags;

  /// FS `meta.json` mtime at last successful index (PLAN §11.5.1).
  final DateTime? fsMetaModifiedAt;

  /// FS `note.md` mtime at last successful index.
  final DateTime? fsMarkdownModifiedAt;

  /// Latest mtime under `attachments/` at last index (null if none).
  final DateTime? fsAttachmentsModifiedAt;
  const NoteRow(
      {required this.id,
      required this.title,
      required this.author,
      required this.createdAt,
      required this.updatedAt,
      required this.deleted,
      this.deletedAt,
      required this.previewSnippet,
      required this.markdown,
      required this.tags,
      this.fsMetaModifiedAt,
      this.fsMarkdownModifiedAt,
      this.fsAttachmentsModifiedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['preview_snippet'] = Variable<String>(previewSnippet);
    map['markdown'] = Variable<String>(markdown);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || fsMetaModifiedAt != null) {
      map['fs_meta_modified_at'] = Variable<DateTime>(fsMetaModifiedAt);
    }
    if (!nullToAbsent || fsMarkdownModifiedAt != null) {
      map['fs_markdown_modified_at'] = Variable<DateTime>(fsMarkdownModifiedAt);
    }
    if (!nullToAbsent || fsAttachmentsModifiedAt != null) {
      map['fs_attachments_modified_at'] =
          Variable<DateTime>(fsAttachmentsModifiedAt);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      previewSnippet: Value(previewSnippet),
      markdown: Value(markdown),
      tags: Value(tags),
      fsMetaModifiedAt: fsMetaModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fsMetaModifiedAt),
      fsMarkdownModifiedAt: fsMarkdownModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fsMarkdownModifiedAt),
      fsAttachmentsModifiedAt: fsAttachmentsModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fsAttachmentsModifiedAt),
    );
  }

  factory NoteRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      previewSnippet: serializer.fromJson<String>(json['previewSnippet']),
      markdown: serializer.fromJson<String>(json['markdown']),
      tags: serializer.fromJson<String>(json['tags']),
      fsMetaModifiedAt:
          serializer.fromJson<DateTime?>(json['fsMetaModifiedAt']),
      fsMarkdownModifiedAt:
          serializer.fromJson<DateTime?>(json['fsMarkdownModifiedAt']),
      fsAttachmentsModifiedAt:
          serializer.fromJson<DateTime?>(json['fsAttachmentsModifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'previewSnippet': serializer.toJson<String>(previewSnippet),
      'markdown': serializer.toJson<String>(markdown),
      'tags': serializer.toJson<String>(tags),
      'fsMetaModifiedAt': serializer.toJson<DateTime?>(fsMetaModifiedAt),
      'fsMarkdownModifiedAt':
          serializer.toJson<DateTime?>(fsMarkdownModifiedAt),
      'fsAttachmentsModifiedAt':
          serializer.toJson<DateTime?>(fsAttachmentsModifiedAt),
    };
  }

  NoteRow copyWith(
          {String? id,
          String? title,
          String? author,
          DateTime? createdAt,
          DateTime? updatedAt,
          bool? deleted,
          Value<DateTime?> deletedAt = const Value.absent(),
          String? previewSnippet,
          String? markdown,
          String? tags,
          Value<DateTime?> fsMetaModifiedAt = const Value.absent(),
          Value<DateTime?> fsMarkdownModifiedAt = const Value.absent(),
          Value<DateTime?> fsAttachmentsModifiedAt = const Value.absent()}) =>
      NoteRow(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        previewSnippet: previewSnippet ?? this.previewSnippet,
        markdown: markdown ?? this.markdown,
        tags: tags ?? this.tags,
        fsMetaModifiedAt: fsMetaModifiedAt.present
            ? fsMetaModifiedAt.value
            : this.fsMetaModifiedAt,
        fsMarkdownModifiedAt: fsMarkdownModifiedAt.present
            ? fsMarkdownModifiedAt.value
            : this.fsMarkdownModifiedAt,
        fsAttachmentsModifiedAt: fsAttachmentsModifiedAt.present
            ? fsAttachmentsModifiedAt.value
            : this.fsAttachmentsModifiedAt,
      );
  NoteRow copyWithCompanion(NotesCompanion data) {
    return NoteRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      previewSnippet: data.previewSnippet.present
          ? data.previewSnippet.value
          : this.previewSnippet,
      markdown: data.markdown.present ? data.markdown.value : this.markdown,
      tags: data.tags.present ? data.tags.value : this.tags,
      fsMetaModifiedAt: data.fsMetaModifiedAt.present
          ? data.fsMetaModifiedAt.value
          : this.fsMetaModifiedAt,
      fsMarkdownModifiedAt: data.fsMarkdownModifiedAt.present
          ? data.fsMarkdownModifiedAt.value
          : this.fsMarkdownModifiedAt,
      fsAttachmentsModifiedAt: data.fsAttachmentsModifiedAt.present
          ? data.fsAttachmentsModifiedAt.value
          : this.fsAttachmentsModifiedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('previewSnippet: $previewSnippet, ')
          ..write('markdown: $markdown, ')
          ..write('tags: $tags, ')
          ..write('fsMetaModifiedAt: $fsMetaModifiedAt, ')
          ..write('fsMarkdownModifiedAt: $fsMarkdownModifiedAt, ')
          ..write('fsAttachmentsModifiedAt: $fsAttachmentsModifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      author,
      createdAt,
      updatedAt,
      deleted,
      deletedAt,
      previewSnippet,
      markdown,
      tags,
      fsMetaModifiedAt,
      fsMarkdownModifiedAt,
      fsAttachmentsModifiedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.deletedAt == this.deletedAt &&
          other.previewSnippet == this.previewSnippet &&
          other.markdown == this.markdown &&
          other.tags == this.tags &&
          other.fsMetaModifiedAt == this.fsMetaModifiedAt &&
          other.fsMarkdownModifiedAt == this.fsMarkdownModifiedAt &&
          other.fsAttachmentsModifiedAt == this.fsAttachmentsModifiedAt);
}

class NotesCompanion extends UpdateCompanion<NoteRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> author;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<DateTime?> deletedAt;
  final Value<String> previewSnippet;
  final Value<String> markdown;
  final Value<String> tags;
  final Value<DateTime?> fsMetaModifiedAt;
  final Value<DateTime?> fsMarkdownModifiedAt;
  final Value<DateTime?> fsAttachmentsModifiedAt;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.previewSnippet = const Value.absent(),
    this.markdown = const Value.absent(),
    this.tags = const Value.absent(),
    this.fsMetaModifiedAt = const Value.absent(),
    this.fsMarkdownModifiedAt = const Value.absent(),
    this.fsAttachmentsModifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.previewSnippet = const Value.absent(),
    this.markdown = const Value.absent(),
    this.tags = const Value.absent(),
    this.fsMetaModifiedAt = const Value.absent(),
    this.fsMarkdownModifiedAt = const Value.absent(),
    this.fsAttachmentsModifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<NoteRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<DateTime>? deletedAt,
    Expression<String>? previewSnippet,
    Expression<String>? markdown,
    Expression<String>? tags,
    Expression<DateTime>? fsMetaModifiedAt,
    Expression<DateTime>? fsMarkdownModifiedAt,
    Expression<DateTime>? fsAttachmentsModifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (previewSnippet != null) 'preview_snippet': previewSnippet,
      if (markdown != null) 'markdown': markdown,
      if (tags != null) 'tags': tags,
      if (fsMetaModifiedAt != null) 'fs_meta_modified_at': fsMetaModifiedAt,
      if (fsMarkdownModifiedAt != null)
        'fs_markdown_modified_at': fsMarkdownModifiedAt,
      if (fsAttachmentsModifiedAt != null)
        'fs_attachments_modified_at': fsAttachmentsModifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? author,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<bool>? deleted,
      Value<DateTime?>? deletedAt,
      Value<String>? previewSnippet,
      Value<String>? markdown,
      Value<String>? tags,
      Value<DateTime?>? fsMetaModifiedAt,
      Value<DateTime?>? fsMarkdownModifiedAt,
      Value<DateTime?>? fsAttachmentsModifiedAt,
      Value<int>? rowid}) {
    return NotesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      previewSnippet: previewSnippet ?? this.previewSnippet,
      markdown: markdown ?? this.markdown,
      tags: tags ?? this.tags,
      fsMetaModifiedAt: fsMetaModifiedAt ?? this.fsMetaModifiedAt,
      fsMarkdownModifiedAt: fsMarkdownModifiedAt ?? this.fsMarkdownModifiedAt,
      fsAttachmentsModifiedAt:
          fsAttachmentsModifiedAt ?? this.fsAttachmentsModifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (previewSnippet.present) {
      map['preview_snippet'] = Variable<String>(previewSnippet.value);
    }
    if (markdown.present) {
      map['markdown'] = Variable<String>(markdown.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (fsMetaModifiedAt.present) {
      map['fs_meta_modified_at'] = Variable<DateTime>(fsMetaModifiedAt.value);
    }
    if (fsMarkdownModifiedAt.present) {
      map['fs_markdown_modified_at'] =
          Variable<DateTime>(fsMarkdownModifiedAt.value);
    }
    if (fsAttachmentsModifiedAt.present) {
      map['fs_attachments_modified_at'] =
          Variable<DateTime>(fsAttachmentsModifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('previewSnippet: $previewSnippet, ')
          ..write('markdown: $markdown, ')
          ..write('tags: $tags, ')
          ..write('fsMetaModifiedAt: $fsMetaModifiedAt, ')
          ..write('fsMarkdownModifiedAt: $fsMarkdownModifiedAt, ')
          ..write('fsAttachmentsModifiedAt: $fsAttachmentsModifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NoteAttachmentsTable extends NoteAttachments
    with TableInfo<$NoteAttachmentsTable, NoteAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<int> rowId = GeneratedColumn<int>(
      'row_id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
      'note_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
      'mime', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
      'sha256', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [rowId, noteId, name, size, mime, sha256];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_attachments';
  @override
  VerificationContext validateIntegrity(Insertable<NoteAttachment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
          _rowIdMeta, rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta));
    }
    if (data.containsKey('note_id')) {
      context.handle(_noteIdMeta,
          noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta));
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    if (data.containsKey('mime')) {
      context.handle(
          _mimeMeta, mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta));
    }
    if (data.containsKey('sha256')) {
      context.handle(_sha256Meta,
          sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowId};
  @override
  NoteAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteAttachment(
      rowId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}row_id'])!,
      noteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size'])!,
      mime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime']),
      sha256: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sha256']),
    );
  }

  @override
  $NoteAttachmentsTable createAlias(String alias) {
    return $NoteAttachmentsTable(attachedDatabase, alias);
  }
}

class NoteAttachment extends DataClass implements Insertable<NoteAttachment> {
  final int rowId;
  final String noteId;
  final String name;
  final int size;
  final String? mime;
  final String? sha256;
  const NoteAttachment(
      {required this.rowId,
      required this.noteId,
      required this.name,
      required this.size,
      this.mime,
      this.sha256});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_id'] = Variable<int>(rowId);
    map['note_id'] = Variable<String>(noteId);
    map['name'] = Variable<String>(name);
    map['size'] = Variable<int>(size);
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    return map;
  }

  NoteAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return NoteAttachmentsCompanion(
      rowId: Value(rowId),
      noteId: Value(noteId),
      name: Value(name),
      size: Value(size),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
      sha256:
          sha256 == null && nullToAbsent ? const Value.absent() : Value(sha256),
    );
  }

  factory NoteAttachment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteAttachment(
      rowId: serializer.fromJson<int>(json['rowId']),
      noteId: serializer.fromJson<String>(json['noteId']),
      name: serializer.fromJson<String>(json['name']),
      size: serializer.fromJson<int>(json['size']),
      mime: serializer.fromJson<String?>(json['mime']),
      sha256: serializer.fromJson<String?>(json['sha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowId': serializer.toJson<int>(rowId),
      'noteId': serializer.toJson<String>(noteId),
      'name': serializer.toJson<String>(name),
      'size': serializer.toJson<int>(size),
      'mime': serializer.toJson<String?>(mime),
      'sha256': serializer.toJson<String?>(sha256),
    };
  }

  NoteAttachment copyWith(
          {int? rowId,
          String? noteId,
          String? name,
          int? size,
          Value<String?> mime = const Value.absent(),
          Value<String?> sha256 = const Value.absent()}) =>
      NoteAttachment(
        rowId: rowId ?? this.rowId,
        noteId: noteId ?? this.noteId,
        name: name ?? this.name,
        size: size ?? this.size,
        mime: mime.present ? mime.value : this.mime,
        sha256: sha256.present ? sha256.value : this.sha256,
      );
  NoteAttachment copyWithCompanion(NoteAttachmentsCompanion data) {
    return NoteAttachment(
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      name: data.name.present ? data.name.value : this.name,
      size: data.size.present ? data.size.value : this.size,
      mime: data.mime.present ? data.mime.value : this.mime,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteAttachment(')
          ..write('rowId: $rowId, ')
          ..write('noteId: $noteId, ')
          ..write('name: $name, ')
          ..write('size: $size, ')
          ..write('mime: $mime, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(rowId, noteId, name, size, mime, sha256);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteAttachment &&
          other.rowId == this.rowId &&
          other.noteId == this.noteId &&
          other.name == this.name &&
          other.size == this.size &&
          other.mime == this.mime &&
          other.sha256 == this.sha256);
}

class NoteAttachmentsCompanion extends UpdateCompanion<NoteAttachment> {
  final Value<int> rowId;
  final Value<String> noteId;
  final Value<String> name;
  final Value<int> size;
  final Value<String?> mime;
  final Value<String?> sha256;
  const NoteAttachmentsCompanion({
    this.rowId = const Value.absent(),
    this.noteId = const Value.absent(),
    this.name = const Value.absent(),
    this.size = const Value.absent(),
    this.mime = const Value.absent(),
    this.sha256 = const Value.absent(),
  });
  NoteAttachmentsCompanion.insert({
    this.rowId = const Value.absent(),
    required String noteId,
    required String name,
    this.size = const Value.absent(),
    this.mime = const Value.absent(),
    this.sha256 = const Value.absent(),
  })  : noteId = Value(noteId),
        name = Value(name);
  static Insertable<NoteAttachment> custom({
    Expression<int>? rowId,
    Expression<String>? noteId,
    Expression<String>? name,
    Expression<int>? size,
    Expression<String>? mime,
    Expression<String>? sha256,
  }) {
    return RawValuesInsertable({
      if (rowId != null) 'row_id': rowId,
      if (noteId != null) 'note_id': noteId,
      if (name != null) 'name': name,
      if (size != null) 'size': size,
      if (mime != null) 'mime': mime,
      if (sha256 != null) 'sha256': sha256,
    });
  }

  NoteAttachmentsCompanion copyWith(
      {Value<int>? rowId,
      Value<String>? noteId,
      Value<String>? name,
      Value<int>? size,
      Value<String?>? mime,
      Value<String?>? sha256}) {
    return NoteAttachmentsCompanion(
      rowId: rowId ?? this.rowId,
      noteId: noteId ?? this.noteId,
      name: name ?? this.name,
      size: size ?? this.size,
      mime: mime ?? this.mime,
      sha256: sha256 ?? this.sha256,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowId.present) {
      map['row_id'] = Variable<int>(rowId.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteAttachmentsCompanion(')
          ..write('rowId: $rowId, ')
          ..write('noteId: $noteId, ')
          ..write('name: $name, ')
          ..write('size: $size, ')
          ..write('mime: $mime, ')
          ..write('sha256: $sha256')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, entityType, entityId, operation, payload, createdAt, retryCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(Insertable<SyncOutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final int id;
  final String entityType;
  final String entityId;
  final String operation;
  final String? payload;
  final DateTime createdAt;
  final int retryCount;
  const SyncOutboxData(
      {required this.id,
      required this.entityType,
      required this.entityId,
      required this.operation,
      this.payload,
      required this.createdAt,
      required this.retryCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<String>(payload);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
    );
  }

  factory SyncOutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      id: serializer.fromJson<int>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String?>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String?>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  SyncOutboxData copyWith(
          {int? id,
          String? entityType,
          String? entityId,
          String? operation,
          Value<String?> payload = const Value.absent(),
          DateTime? createdAt,
          int? retryCount}) =>
      SyncOutboxData(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        operation: operation ?? this.operation,
        payload: payload.present ? payload.value : this.payload,
        createdAt: createdAt ?? this.createdAt,
        retryCount: retryCount ?? this.retryCount,
      );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      id: data.id.present ? data.id.value : this.id,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, entityType, entityId, operation, payload, createdAt, retryCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<int> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String?> payload;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String entityType,
    required String entityId,
    required String operation,
    this.payload = const Value.absent(),
    required DateTime createdAt,
    this.retryCount = const Value.absent(),
  })  : entityType = Value(entityType),
        entityId = Value(entityId),
        operation = Value(operation),
        createdAt = Value(createdAt);
  static Insertable<SyncOutboxData> custom({
    Expression<int>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
    });
  }

  SyncOutboxCompanion copyWith(
      {Value<int>? id,
      Value<String>? entityType,
      Value<String>? entityId,
      Value<String>? operation,
      Value<String?>? payload,
      Value<DateTime>? createdAt,
      Value<int>? retryCount}) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }
}

class $DevicesTable extends Devices with TableInfo<$DevicesTable, DeviceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
      'peer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('device'));
  static const VerificationMeta _trustedMeta =
      const VerificationMeta('trusted');
  @override
  late final GeneratedColumn<bool> trusted = GeneratedColumn<bool>(
      'trusted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("trusted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastSeenAtMeta =
      const VerificationMeta('lastSeenAt');
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
      'last_seen_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [peerId, name, icon, trusted, lastSeenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(Insertable<DeviceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_id')) {
      context.handle(_peerIdMeta,
          peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta));
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('trusted')) {
      context.handle(_trustedMeta,
          trusted.isAcceptableOrUnknown(data['trusted']!, _trustedMeta));
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
          _lastSeenAtMeta,
          lastSeenAt.isAcceptableOrUnknown(
              data['last_seen_at']!, _lastSeenAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerId};
  @override
  DeviceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceRow(
      peerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}peer_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      trusted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}trusted'])!,
      lastSeenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_seen_at']),
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class DeviceRow extends DataClass implements Insertable<DeviceRow> {
  final String peerId;
  final String name;
  final String icon;
  final bool trusted;
  final DateTime? lastSeenAt;
  const DeviceRow(
      {required this.peerId,
      required this.name,
      required this.icon,
      required this.trusted,
      this.lastSeenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_id'] = Variable<String>(peerId);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['trusted'] = Variable<bool>(trusted);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    }
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      peerId: Value(peerId),
      name: Value(name),
      icon: Value(icon),
      trusted: Value(trusted),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
    );
  }

  factory DeviceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceRow(
      peerId: serializer.fromJson<String>(json['peerId']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      trusted: serializer.fromJson<bool>(json['trusted']),
      lastSeenAt: serializer.fromJson<DateTime?>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerId': serializer.toJson<String>(peerId),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'trusted': serializer.toJson<bool>(trusted),
      'lastSeenAt': serializer.toJson<DateTime?>(lastSeenAt),
    };
  }

  DeviceRow copyWith(
          {String? peerId,
          String? name,
          String? icon,
          bool? trusted,
          Value<DateTime?> lastSeenAt = const Value.absent()}) =>
      DeviceRow(
        peerId: peerId ?? this.peerId,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        trusted: trusted ?? this.trusted,
        lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
      );
  DeviceRow copyWithCompanion(DevicesCompanion data) {
    return DeviceRow(
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      trusted: data.trusted.present ? data.trusted.value : this.trusted,
      lastSeenAt:
          data.lastSeenAt.present ? data.lastSeenAt.value : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceRow(')
          ..write('peerId: $peerId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('trusted: $trusted, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(peerId, name, icon, trusted, lastSeenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceRow &&
          other.peerId == this.peerId &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.trusted == this.trusted &&
          other.lastSeenAt == this.lastSeenAt);
}

class DevicesCompanion extends UpdateCompanion<DeviceRow> {
  final Value<String> peerId;
  final Value<String> name;
  final Value<String> icon;
  final Value<bool> trusted;
  final Value<DateTime?> lastSeenAt;
  final Value<int> rowid;
  const DevicesCompanion({
    this.peerId = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.trusted = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String peerId,
    required String name,
    this.icon = const Value.absent(),
    this.trusted = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : peerId = Value(peerId),
        name = Value(name);
  static Insertable<DeviceRow> custom({
    Expression<String>? peerId,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<bool>? trusted,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerId != null) 'peer_id': peerId,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (trusted != null) 'trusted': trusted,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith(
      {Value<String>? peerId,
      Value<String>? name,
      Value<String>? icon,
      Value<bool>? trusted,
      Value<DateTime?>? lastSeenAt,
      Value<int>? rowid}) {
    return DevicesCompanion(
      peerId: peerId ?? this.peerId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      trusted: trusted ?? this.trusted,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (trusted.present) {
      map['trusted'] = Variable<bool>(trusted.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('peerId: $peerId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('trusted: $trusted, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MeshPadDatabase extends GeneratedDatabase {
  _$MeshPadDatabase(QueryExecutor e) : super(e);
  $MeshPadDatabaseManager get managers => $MeshPadDatabaseManager(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $NoteAttachmentsTable noteAttachments =
      $NoteAttachmentsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [notes, noteAttachments, syncOutbox, devices];
}

typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  required String id,
  Value<String> title,
  Value<String> author,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<DateTime?> deletedAt,
  Value<String> previewSnippet,
  Value<String> markdown,
  Value<String> tags,
  Value<DateTime?> fsMetaModifiedAt,
  Value<DateTime?> fsMarkdownModifiedAt,
  Value<DateTime?> fsAttachmentsModifiedAt,
  Value<int> rowid,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> author,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<DateTime?> deletedAt,
  Value<String> previewSnippet,
  Value<String> markdown,
  Value<String> tags,
  Value<DateTime?> fsMetaModifiedAt,
  Value<DateTime?> fsMarkdownModifiedAt,
  Value<DateTime?> fsAttachmentsModifiedAt,
  Value<int> rowid,
});

class $$NotesTableFilterComposer
    extends Composer<_$MeshPadDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get previewSnippet => $composableBuilder(
      column: $table.previewSnippet,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get markdown => $composableBuilder(
      column: $table.markdown, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fsMetaModifiedAt => $composableBuilder(
      column: $table.fsMetaModifiedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fsMarkdownModifiedAt => $composableBuilder(
      column: $table.fsMarkdownModifiedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fsAttachmentsModifiedAt => $composableBuilder(
      column: $table.fsAttachmentsModifiedAt,
      builder: (column) => ColumnFilters(column));
}

class $$NotesTableOrderingComposer
    extends Composer<_$MeshPadDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get previewSnippet => $composableBuilder(
      column: $table.previewSnippet,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get markdown => $composableBuilder(
      column: $table.markdown, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fsMetaModifiedAt => $composableBuilder(
      column: $table.fsMetaModifiedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fsMarkdownModifiedAt => $composableBuilder(
      column: $table.fsMarkdownModifiedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fsAttachmentsModifiedAt => $composableBuilder(
      column: $table.fsAttachmentsModifiedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$NotesTableAnnotationComposer
    extends Composer<_$MeshPadDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get previewSnippet => $composableBuilder(
      column: $table.previewSnippet, builder: (column) => column);

  GeneratedColumn<String> get markdown =>
      $composableBuilder(column: $table.markdown, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<DateTime> get fsMetaModifiedAt => $composableBuilder(
      column: $table.fsMetaModifiedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get fsMarkdownModifiedAt => $composableBuilder(
      column: $table.fsMarkdownModifiedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get fsAttachmentsModifiedAt => $composableBuilder(
      column: $table.fsAttachmentsModifiedAt, builder: (column) => column);
}

class $$NotesTableTableManager extends RootTableManager<
    _$MeshPadDatabase,
    $NotesTable,
    NoteRow,
    $$NotesTableFilterComposer,
    $$NotesTableOrderingComposer,
    $$NotesTableAnnotationComposer,
    $$NotesTableCreateCompanionBuilder,
    $$NotesTableUpdateCompanionBuilder,
    (NoteRow, BaseReferences<_$MeshPadDatabase, $NotesTable, NoteRow>),
    NoteRow,
    PrefetchHooks Function()> {
  $$NotesTableTableManager(_$MeshPadDatabase db, $NotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String> previewSnippet = const Value.absent(),
            Value<String> markdown = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<DateTime?> fsMetaModifiedAt = const Value.absent(),
            Value<DateTime?> fsMarkdownModifiedAt = const Value.absent(),
            Value<DateTime?> fsAttachmentsModifiedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotesCompanion(
            id: id,
            title: title,
            author: author,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            deletedAt: deletedAt,
            previewSnippet: previewSnippet,
            markdown: markdown,
            tags: tags,
            fsMetaModifiedAt: fsMetaModifiedAt,
            fsMarkdownModifiedAt: fsMarkdownModifiedAt,
            fsAttachmentsModifiedAt: fsAttachmentsModifiedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> title = const Value.absent(),
            Value<String> author = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<bool> deleted = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String> previewSnippet = const Value.absent(),
            Value<String> markdown = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<DateTime?> fsMetaModifiedAt = const Value.absent(),
            Value<DateTime?> fsMarkdownModifiedAt = const Value.absent(),
            Value<DateTime?> fsAttachmentsModifiedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotesCompanion.insert(
            id: id,
            title: title,
            author: author,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deleted: deleted,
            deletedAt: deletedAt,
            previewSnippet: previewSnippet,
            markdown: markdown,
            tags: tags,
            fsMetaModifiedAt: fsMetaModifiedAt,
            fsMarkdownModifiedAt: fsMarkdownModifiedAt,
            fsAttachmentsModifiedAt: fsAttachmentsModifiedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotesTableProcessedTableManager = ProcessedTableManager<
    _$MeshPadDatabase,
    $NotesTable,
    NoteRow,
    $$NotesTableFilterComposer,
    $$NotesTableOrderingComposer,
    $$NotesTableAnnotationComposer,
    $$NotesTableCreateCompanionBuilder,
    $$NotesTableUpdateCompanionBuilder,
    (NoteRow, BaseReferences<_$MeshPadDatabase, $NotesTable, NoteRow>),
    NoteRow,
    PrefetchHooks Function()>;
typedef $$NoteAttachmentsTableCreateCompanionBuilder = NoteAttachmentsCompanion
    Function({
  Value<int> rowId,
  required String noteId,
  required String name,
  Value<int> size,
  Value<String?> mime,
  Value<String?> sha256,
});
typedef $$NoteAttachmentsTableUpdateCompanionBuilder = NoteAttachmentsCompanion
    Function({
  Value<int> rowId,
  Value<String> noteId,
  Value<String> name,
  Value<int> size,
  Value<String?> mime,
  Value<String?> sha256,
});

class $$NoteAttachmentsTableFilterComposer
    extends Composer<_$MeshPadDatabase, $NoteAttachmentsTable> {
  $$NoteAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rowId => $composableBuilder(
      column: $table.rowId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteId => $composableBuilder(
      column: $table.noteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mime => $composableBuilder(
      column: $table.mime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnFilters(column));
}

class $$NoteAttachmentsTableOrderingComposer
    extends Composer<_$MeshPadDatabase, $NoteAttachmentsTable> {
  $$NoteAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rowId => $composableBuilder(
      column: $table.rowId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteId => $composableBuilder(
      column: $table.noteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mime => $composableBuilder(
      column: $table.mime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sha256 => $composableBuilder(
      column: $table.sha256, builder: (column) => ColumnOrderings(column));
}

class $$NoteAttachmentsTableAnnotationComposer
    extends Composer<_$MeshPadDatabase, $NoteAttachmentsTable> {
  $$NoteAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);
}

class $$NoteAttachmentsTableTableManager extends RootTableManager<
    _$MeshPadDatabase,
    $NoteAttachmentsTable,
    NoteAttachment,
    $$NoteAttachmentsTableFilterComposer,
    $$NoteAttachmentsTableOrderingComposer,
    $$NoteAttachmentsTableAnnotationComposer,
    $$NoteAttachmentsTableCreateCompanionBuilder,
    $$NoteAttachmentsTableUpdateCompanionBuilder,
    (
      NoteAttachment,
      BaseReferences<_$MeshPadDatabase, $NoteAttachmentsTable, NoteAttachment>
    ),
    NoteAttachment,
    PrefetchHooks Function()> {
  $$NoteAttachmentsTableTableManager(
      _$MeshPadDatabase db, $NoteAttachmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteAttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> rowId = const Value.absent(),
            Value<String> noteId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> size = const Value.absent(),
            Value<String?> mime = const Value.absent(),
            Value<String?> sha256 = const Value.absent(),
          }) =>
              NoteAttachmentsCompanion(
            rowId: rowId,
            noteId: noteId,
            name: name,
            size: size,
            mime: mime,
            sha256: sha256,
          ),
          createCompanionCallback: ({
            Value<int> rowId = const Value.absent(),
            required String noteId,
            required String name,
            Value<int> size = const Value.absent(),
            Value<String?> mime = const Value.absent(),
            Value<String?> sha256 = const Value.absent(),
          }) =>
              NoteAttachmentsCompanion.insert(
            rowId: rowId,
            noteId: noteId,
            name: name,
            size: size,
            mime: mime,
            sha256: sha256,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NoteAttachmentsTableProcessedTableManager = ProcessedTableManager<
    _$MeshPadDatabase,
    $NoteAttachmentsTable,
    NoteAttachment,
    $$NoteAttachmentsTableFilterComposer,
    $$NoteAttachmentsTableOrderingComposer,
    $$NoteAttachmentsTableAnnotationComposer,
    $$NoteAttachmentsTableCreateCompanionBuilder,
    $$NoteAttachmentsTableUpdateCompanionBuilder,
    (
      NoteAttachment,
      BaseReferences<_$MeshPadDatabase, $NoteAttachmentsTable, NoteAttachment>
    ),
    NoteAttachment,
    PrefetchHooks Function()>;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> id,
  required String entityType,
  required String entityId,
  required String operation,
  Value<String?> payload,
  required DateTime createdAt,
  Value<int> retryCount,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<int> id,
  Value<String> entityType,
  Value<String> entityId,
  Value<String> operation,
  Value<String?> payload,
  Value<DateTime> createdAt,
  Value<int> retryCount,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$MeshPadDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$MeshPadDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$MeshPadDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);
}

class $$SyncOutboxTableTableManager extends RootTableManager<
    _$MeshPadDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$MeshPadDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()> {
  $$SyncOutboxTableTableManager(_$MeshPadDatabase db, $SyncOutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entityType = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<String?> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
          }) =>
              SyncOutboxCompanion(
            id: id,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: payload,
            createdAt: createdAt,
            retryCount: retryCount,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entityType,
            required String entityId,
            required String operation,
            Value<String?> payload = const Value.absent(),
            required DateTime createdAt,
            Value<int> retryCount = const Value.absent(),
          }) =>
              SyncOutboxCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: payload,
            createdAt: createdAt,
            retryCount: retryCount,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncOutboxTableProcessedTableManager = ProcessedTableManager<
    _$MeshPadDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$MeshPadDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()>;
typedef $$DevicesTableCreateCompanionBuilder = DevicesCompanion Function({
  required String peerId,
  required String name,
  Value<String> icon,
  Value<bool> trusted,
  Value<DateTime?> lastSeenAt,
  Value<int> rowid,
});
typedef $$DevicesTableUpdateCompanionBuilder = DevicesCompanion Function({
  Value<String> peerId,
  Value<String> name,
  Value<String> icon,
  Value<bool> trusted,
  Value<DateTime?> lastSeenAt,
  Value<int> rowid,
});

class $$DevicesTableFilterComposer
    extends Composer<_$MeshPadDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerId => $composableBuilder(
      column: $table.peerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get trusted => $composableBuilder(
      column: $table.trusted, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnFilters(column));
}

class $$DevicesTableOrderingComposer
    extends Composer<_$MeshPadDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerId => $composableBuilder(
      column: $table.peerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get trusted => $composableBuilder(
      column: $table.trusted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => ColumnOrderings(column));
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$MeshPadDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<bool> get trusted =>
      $composableBuilder(column: $table.trusted, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
      column: $table.lastSeenAt, builder: (column) => column);
}

class $$DevicesTableTableManager extends RootTableManager<
    _$MeshPadDatabase,
    $DevicesTable,
    DeviceRow,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (DeviceRow, BaseReferences<_$MeshPadDatabase, $DevicesTable, DeviceRow>),
    DeviceRow,
    PrefetchHooks Function()> {
  $$DevicesTableTableManager(_$MeshPadDatabase db, $DevicesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> peerId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<bool> trusted = const Value.absent(),
            Value<DateTime?> lastSeenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion(
            peerId: peerId,
            name: name,
            icon: icon,
            trusted: trusted,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String peerId,
            required String name,
            Value<String> icon = const Value.absent(),
            Value<bool> trusted = const Value.absent(),
            Value<DateTime?> lastSeenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DevicesCompanion.insert(
            peerId: peerId,
            name: name,
            icon: icon,
            trusted: trusted,
            lastSeenAt: lastSeenAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DevicesTableProcessedTableManager = ProcessedTableManager<
    _$MeshPadDatabase,
    $DevicesTable,
    DeviceRow,
    $$DevicesTableFilterComposer,
    $$DevicesTableOrderingComposer,
    $$DevicesTableAnnotationComposer,
    $$DevicesTableCreateCompanionBuilder,
    $$DevicesTableUpdateCompanionBuilder,
    (DeviceRow, BaseReferences<_$MeshPadDatabase, $DevicesTable, DeviceRow>),
    DeviceRow,
    PrefetchHooks Function()>;

class $MeshPadDatabaseManager {
  final _$MeshPadDatabase _db;
  $MeshPadDatabaseManager(this._db);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$NoteAttachmentsTableTableManager get noteAttachments =>
      $$NoteAttachmentsTableTableManager(_db, _db.noteAttachments);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
}
