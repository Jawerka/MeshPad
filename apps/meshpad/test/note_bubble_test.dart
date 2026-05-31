import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:meshpad/core/models/notes_feed_state.dart';
import 'package:meshpad/core/providers/notes_providers.dart';
import 'package:meshpad/core/services/notes_service.dart';
import 'package:meshpad/features/feed/note_bubble.dart';

class _FakeNotesService implements NotesService {
  @override
  Future<String?> get localDataDir async => null;

  @override
  Uri? attachmentUri(String noteId, String fileName) => null;

  @override
  Uri? attachmentThumbUri(String noteId, String fileName) => null;

  @override
  Future<int> countActiveNotes({String? tag}) async => 0;

  @override
  Future<List<String>> listDistinctTags() async => const [];

  @override
  Future<List<Note>> listNotesSlice({
    required int offset,
    int limit = 40,
    NoteSort sort = NoteSort.createdAt,
    String? tag,
  }) async =>
      [];

  @override
  Future<void> setNoteTags(String id, List<String> tags) async {}

  @override
  Future<List<Note>> listTrash() async => [];

  @override
  Future<List<NoteSearchHit>> searchNotes(String query, {int limit = 50}) async =>
      [];

  @override
  Future<void> createNote({
    String title = '',
    required String markdown,
    List<String> attachmentPaths = const [],
    List<NoteAttachmentBytes> attachmentBytes = const [],
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {}

  @override
  Future<void> updateNote(String id, {String? title, String? markdown}) async {}

  @override
  Future<void> addAttachment(
    String noteId,
    String sourcePath, {
    AttachmentCopyProgressCallback? onAttachmentProgress,
    List<int>? bytes,
    String? fileName,
  }) async {}

  @override
  Future<void> deleteNote(String id) async {}

  @override
  Future<void> restoreNote(String id) async {}

  @override
  Future<int> pendingOutboxCount() async => 0;

  @override
  Future<Set<String>> pendingOutboxNoteIds() async => {};
}

class _EmptyNotesListNotifier extends NotesListNotifier {
  @override
  Future<NotesFeedState> build() async => const NotesFeedState();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  testWidgets('attachment-only note hides empty placeholder', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final note = Note(
      id: 'note-1',
      title: '',
      markdown: '',
      author: 'test',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      attachments: const [
        AttachmentMeta(name: 'photo.jpg', size: 1024, mime: 'image/jpeg'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notesListProvider.overrideWith(_EmptyNotesListNotifier.new),
          notesServiceProvider.overrideWith(
            (ref) async => _FakeNotesService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: NoteBubble(note: note),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Пустая заметка'), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}
