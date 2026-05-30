import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad_api_client/meshpad_api_client.dart';

/// UI-facing notes access — local repository or remote HTTP API (Web).
abstract class NotesService {
  Future<String?> get localDataDir;

  Uri? attachmentUri(String noteId, String fileName);

  Future<int> countActiveNotes();

  Future<List<Note>> listNotesSlice({
    required int offset,
    int limit = 40,
  });

  Future<List<Note>> listTrash();

  Future<List<NoteSearchHit>> searchNotes(String query, {int limit = 50});

  Future<void> createNote({
    String title = '',
    required String markdown,
    List<String> attachmentPaths = const [],
    AttachmentCopyProgressCallback? onAttachmentProgress,
  });

  Future<void> updateNote(String id, {String? title, String? markdown});

  Future<void> addAttachment(
    String noteId,
    String sourcePath, {
    AttachmentCopyProgressCallback? onAttachmentProgress,
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
  Future<int> countActiveNotes() => repository.countActiveNotes();

  @override
  Future<List<Note>> listNotesSlice({
    required int offset,
    int limit = 40,
  }) =>
      repository.listNotesSlice(offset: offset, limit: limit);

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
  Future<void> addAttachment(
    String noteId,
    String sourcePath, {
    AttachmentCopyProgressCallback? onAttachmentProgress,
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
  List<Note>? _activeCache;

  @override
  Future<String?> get localDataDir async => null;

  @override
  Uri? attachmentUri(String noteId, String fileName) =>
      _client.attachmentUri(noteId, fileName);

  Future<List<Note>> _activeNotes() async {
    _activeCache ??= await _client.listNotes();
    return _activeCache!;
  }

  void _invalidate() => _activeCache = null;

  @override
  Future<int> countActiveNotes() async => (await _activeNotes()).length;

  @override
  Future<List<Note>> listNotesSlice({
    required int offset,
    int limit = 40,
  }) async {
    final all = await _activeNotes();
    if (offset >= all.length) return [];
    final end = offset + limit;
    return all.sublist(offset, end > all.length ? all.length : end);
  }

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
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    if (attachmentPaths.isNotEmpty) {
      throw const SyncTransportException(
        'Вложения в Web-клиенте пока не поддерживаются',
      );
    }
    await _client.createNote(title: title, markdown: markdown);
    _invalidate();
  }

  @override
  Future<void> updateNote(String id, {String? title, String? markdown}) async {
    await _client.updateNote(id, title: title, markdown: markdown);
    _invalidate();
  }

  @override
  Future<void> addAttachment(
    String noteId,
    String sourcePath, {
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) {
    throw const SyncTransportException(
      'Вложения в Web-клиенте пока не поддерживаются',
    );
  }

  @override
  Future<void> deleteNote(String id) async {
    await _client.deleteNote(id);
    _invalidate();
  }

  @override
  Future<void> restoreNote(String id) async {
    await _client.restoreNote(id);
    _invalidate();
  }

  @override
  Future<int> pendingOutboxCount() async => 0;

  @override
  Future<Set<String>> pendingOutboxNoteIds() async => {};
}
