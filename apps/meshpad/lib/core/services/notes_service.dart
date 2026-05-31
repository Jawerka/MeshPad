import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_api_client/meshpad_api_client.dart';

/// In-memory attachment payload for Web upload (no local file path).
class NoteAttachmentBytes {
  const NoteAttachmentBytes({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

/// UI-facing notes access — local repository or remote HTTP API (Web).
abstract class NotesService {
  Future<String?> get localDataDir;

  Uri? attachmentUri(String noteId, String fileName);

  Uri? attachmentThumbUri(String noteId, String fileName) => null;

  Future<int> countActiveNotes({String? tag});

  Future<List<String>> listDistinctTags();

  Future<List<Note>> listNotesSlice({
    required int offset,
    int limit = 40,
    NoteSort sort = NoteSort.createdAt,
    String? tag,
  });

  Future<List<Note>> listTrash();

  Future<List<NoteSearchHit>> searchNotes(String query, {int limit = 50});

  Future<void> createNote({
    String title = '',
    required String markdown,
    List<String> attachmentPaths = const [],
    List<NoteAttachmentBytes> attachmentBytes = const [],
    AttachmentCopyProgressCallback? onAttachmentProgress,
  });

  Future<void> updateNote(String id, {String? title, String? markdown});

  Future<void> setNoteTags(String id, List<String> tags);

  Future<void> addAttachment(
    String noteId,
    String sourcePath, {
    AttachmentCopyProgressCallback? onAttachmentProgress,
    List<int>? bytes,
    String? fileName,
  });

  Future<void> deleteNote(String id);

  Future<void> restoreNote(String id);

  Future<int> pendingOutboxCount();

  Future<Set<String>> pendingOutboxNoteIds();
}

class LocalNotesService implements NotesService {
  LocalNotesService({
    required this.repository,
    required this.dataDir,
  });

  final NoteRepository repository;
  final String dataDir;

  @override
  Future<String?> get localDataDir async => dataDir;

  @override
  Uri? attachmentUri(String noteId, String fileName) => null;

  @override
  Uri? attachmentThumbUri(String noteId, String fileName) => null;

  @override
  Future<int> countActiveNotes({String? tag}) =>
      repository.countActiveNotes(tag: tag);

  @override
  Future<List<String>> listDistinctTags() => repository.listDistinctTags();

  @override
  Future<List<Note>> listNotesSlice({
    required int offset,
    int limit = 40,
    NoteSort sort = NoteSort.createdAt,
    String? tag,
  }) =>
      repository.listNotesSlice(
        offset: offset,
        limit: limit,
        sort: sort,
        tag: tag,
      );

  @override
  Future<List<Note>> listTrash() => repository.listTrash();

  @override
  Future<List<NoteSearchHit>> searchNotes(String query, {int limit = 50}) =>
      repository.searchNotes(query, limit: limit);

  @override
  Future<void> createNote({
    String title = '',
    required String markdown,
    List<String> attachmentPaths = const [],
    List<NoteAttachmentBytes> attachmentBytes = const [],
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    await repository.createNote(
      title: title,
      markdown: markdown,
      attachmentPaths: attachmentPaths,
      onAttachmentProgress: onAttachmentProgress,
    );
  }

  @override
  Future<void> updateNote(String id, {String? title, String? markdown}) =>
      repository.updateNote(id, title: title, markdown: markdown);

  @override
  Future<void> setNoteTags(String id, List<String> tags) async {
    await repository.setNoteTags(id, tags);
  }

  @override
  Future<void> addAttachment(
    String noteId,
    String sourcePath, {
    AttachmentCopyProgressCallback? onAttachmentProgress,
    List<int>? bytes,
    String? fileName,
  }) =>
      repository.addAttachment(
        noteId,
        sourcePath,
        onAttachmentProgress: onAttachmentProgress,
      );

  @override
  Future<void> deleteNote(String id) => repository.deleteNote(id);

  @override
  Future<void> restoreNote(String id) => repository.restoreNote(id);

  @override
  Future<int> pendingOutboxCount() => repository.pendingOutboxCount();

  @override
  Future<Set<String>> pendingOutboxNoteIds() =>
      repository.pendingOutboxNoteIds();
}

class RemoteNotesService implements NotesService {
  RemoteNotesService(this._client);

  final MeshPadApiClient _client;

  @override
  Future<String?> get localDataDir async => null;

  @override
  Uri? attachmentUri(String noteId, String fileName) =>
      _client.attachmentUri(noteId, fileName);

  @override
  Uri? attachmentThumbUri(String noteId, String fileName) =>
      _client.attachmentThumbUri(noteId, fileName);

  @override
  Future<int> countActiveNotes({String? tag}) => _client.countActiveNotes();

  @override
  Future<List<String>> listDistinctTags() async => const [];

  @override
  Future<List<Note>> listNotesSlice({
    required int offset,
    int limit = 40,
    NoteSort sort = NoteSort.createdAt,
    String? tag,
  }) =>
      _client.listNotesSlice(offset: offset, limit: limit, sort: sort);

  @override
  Future<List<Note>> listTrash() => _client.listTrash();

  @override
  Future<List<NoteSearchHit>> searchNotes(String query, {int limit = 50}) =>
      _client.searchNotes(query);

  @override
  Future<void> createNote({
    String title = '',
    required String markdown,
    List<String> attachmentPaths = const [],
    List<NoteAttachmentBytes> attachmentBytes = const [],
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    if (attachmentPaths.isNotEmpty) {
      throw const SyncTransportException(
        'Локальные пути вложений недоступны в Web-клиенте',
      );
    }

    final note = await _client.createNote(title: title, markdown: markdown);
    final uploads = attachmentBytes;
    for (var i = 0; i < uploads.length; i++) {
      final upload = uploads[i];
      onAttachmentProgress?.call(
        AttachmentCopyProgress(
          fileName: upload.name,
          copiedBytes: 0,
          totalBytes: upload.bytes.length,
          fileIndex: i + 1,
          fileCount: uploads.length,
        ),
      );
      await _client.uploadAttachment(
        noteId: note.id,
        fileName: upload.name,
        bytes: upload.bytes,
      );
      onAttachmentProgress?.call(
        AttachmentCopyProgress(
          fileName: upload.name,
          copiedBytes: upload.bytes.length,
          totalBytes: upload.bytes.length,
          fileIndex: i + 1,
          fileCount: uploads.length,
        ),
      );
    }
  }

  @override
  Future<void> updateNote(String id, {String? title, String? markdown}) async {
    await _client.updateNote(id, title: title, markdown: markdown);
  }

  @override
  Future<void> setNoteTags(String id, List<String> tags) async {
    throw UnsupportedError('Теги недоступны в Web-клиенте');
  }

  @override
  Future<void> addAttachment(
    String noteId,
    String sourcePath, {
    AttachmentCopyProgressCallback? onAttachmentProgress,
    List<int>? bytes,
    String? fileName,
  }) async {
    if (bytes == null || fileName == null) {
      throw const SyncTransportException(
        'Добавление вложений по пути недоступно в Web-клиенте',
      );
    }
    onAttachmentProgress?.call(
      AttachmentCopyProgress(
        fileName: fileName,
        copiedBytes: 0,
        totalBytes: bytes.length,
      ),
    );
    await _client.uploadAttachment(
      noteId: noteId,
      fileName: fileName,
      bytes: bytes,
    );
    onAttachmentProgress?.call(
      AttachmentCopyProgress(
        fileName: fileName,
        copiedBytes: bytes.length,
        totalBytes: bytes.length,
      ),
    );
  }

  @override
  Future<void> deleteNote(String id) async {
    await _client.deleteNote(id);
  }

  @override
  Future<void> restoreNote(String id) async {
    await _client.restoreNote(id);
  }

  @override
  Future<int> pendingOutboxCount() async => 0;

  @override
  Future<Set<String>> pendingOutboxNoteIds() async => {};
}
