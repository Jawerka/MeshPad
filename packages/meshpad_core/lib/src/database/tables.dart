import 'package:drift/drift.dart';

@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get author => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get previewSnippet => text().withDefault(const Constant(''))();
  TextColumn get markdown => text().withDefault(const Constant(''))();
  TextColumn get tags => text().withDefault(const Constant('[]'))();

  /// FS `meta.json` mtime at last successful index (PLAN §11.5.1).
  DateTimeColumn get fsMetaModifiedAt => dateTime().nullable()();

  /// FS `note.md` mtime at last successful index.
  DateTimeColumn get fsMarkdownModifiedAt => dateTime().nullable()();

  /// Latest mtime under `attachments/` at last index (null if none).
  DateTimeColumn get fsAttachmentsModifiedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NoteAttachments extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get noteId => text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  IntColumn get size => integer().withDefault(const Constant(0))();
  TextColumn get mime => text().nullable()();
  TextColumn get sha256 => text().nullable()();
}

class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payload => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

@DataClassName('DeviceRow')
class Devices extends Table {
  TextColumn get peerId => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('device'))();
  BoolColumn get trusted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSeenAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {peerId};
}
