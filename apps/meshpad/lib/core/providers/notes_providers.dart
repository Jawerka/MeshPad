import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_core/meshpad_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _defaultAuthor = 'Это устройство';

final dataDirProvider = FutureProvider<String>((ref) async {
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, 'meshpad');
});

final noteRepositoryProvider = FutureProvider<NoteRepository>((ref) async {
  final dataDir = await ref.watch(dataDirProvider.future);
  final db = createMeshPadDatabase(dataDir);
  ref.onDispose(db.close);
  final repo = createNoteRepository(
    dataDir: dataDir,
    defaultAuthor: _defaultAuthor,
    database: db,
  );
  await repo.reconcileFromFilesystem();
  return repo;
});

enum FeedMode { feed, trash }

final feedModeProvider = StateProvider<FeedMode>((ref) => FeedMode.feed);

final notesListProvider = AsyncNotifierProvider<NotesListNotifier, List<Note>>(
  NotesListNotifier.new,
);

class NotesListNotifier extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() async {
    final repo = await ref.watch(noteRepositoryProvider.future);
    ref.listen(feedModeProvider, (previous, next) {
      if (previous != next) {
        ref.invalidateSelf();
      }
    });
    return _load(repo);
  }

  Future<List<Note>> _load(NoteRepository repo) {
    return switch (ref.read(feedModeProvider)) {
      FeedMode.feed => repo.listNotes(sort: NoteSort.createdAt),
      FeedMode.trash => repo.listTrash(),
    };
  }

  Future<void> reload() async {
    final repo = await ref.read(noteRepositoryProvider.future);
    state = AsyncData(await _load(repo));
  }

  Future<void> createNote({String title = '', required String markdown}) async {
    final repo = await ref.read(noteRepositoryProvider.future);
    await repo.createNote(title: title, markdown: markdown);
    await reload();
  }

  Future<void> updateNote(String id, {String? title, String? markdown}) async {
    final repo = await ref.read(noteRepositoryProvider.future);
    await repo.updateNote(id, title: title, markdown: markdown);
    await reload();
  }

  Future<void> deleteNote(String id) async {
    final repo = await ref.read(noteRepositoryProvider.future);
    await repo.deleteNote(id);
    await reload();
  }

  Future<void> restoreNote(String id) async {
    final repo = await ref.read(noteRepositoryProvider.future);
    await repo.restoreNote(id);
    await reload();
  }
}
