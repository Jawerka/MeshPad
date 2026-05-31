import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_api_client/meshpad_api_client.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../models/notes_feed_state.dart';
import '../services/notes_service.dart';
import '../storage/app_settings_store.dart';
import '../storage/web_api_settings_store.dart';

const _defaultAuthor = '';

final isWebClientProvider = Provider<bool>((ref) => kIsWeb);

final webApiSettingsStoreProvider = Provider<WebApiSettingsStore>((ref) {
  return WebApiSettingsStore();
});

final webApiBaseUrlProvider = FutureProvider<String>((ref) async {
  final store = ref.watch(webApiSettingsStoreProvider);
  return store.loadBaseUrl();
});

final appSettingsStoreProvider = Provider<AppSettingsStore>((ref) {
  return AppSettingsStore();
});

final dataDirProvider = FutureProvider<String?>((ref) async {
  if (ref.watch(isWebClientProvider)) return null;
  final store = ref.watch(appSettingsStoreProvider);
  return store.loadDataDir();
});

final customDataDirProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(isWebClientProvider)) return false;
  final store = ref.watch(appSettingsStoreProvider);
  return store.isUsingCustomDataDir();
});

final noteRepositoryProvider = FutureProvider<NoteRepository>((ref) async {
  if (ref.watch(isWebClientProvider)) {
    throw StateError('NoteRepository is unavailable in Web client mode');
  }
  final dataDir = await ref.watch(dataDirProvider.future);
  final db = createMeshPadDatabase(dataDir!);
  ref.onDispose(db.close);
  final repo = createNoteRepository(
    dataDir: dataDir,
    defaultAuthor: _defaultAuthor,
    database: db,
  );
  await repo.reconcileFromFilesystem();
  return repo;
});

final notesServiceProvider = FutureProvider<NotesService>((ref) async {
  if (ref.watch(isWebClientProvider)) {
    final baseUrl = await ref.watch(webApiBaseUrlProvider.future);
    final client = MeshPadApiClient(baseUrl: baseUrl);
    ref.onDispose(client.close);
    await client.checkHealth();
    return RemoteNotesService(client);
  }

  final dataDir = await ref.watch(dataDirProvider.future);
  final repo = await ref.watch(noteRepositoryProvider.future);
  return LocalNotesService(repository: repo, dataDir: dataDir!);
});

enum FeedMode { feed, trash }

final feedModeProvider = StateProvider<FeedMode>((ref) => FeedMode.feed);

final feedSearchQueryProvider = StateProvider<String>((ref) => '');

final feedSortProvider = NotifierProvider<FeedSortNotifier, NoteSort>(
  FeedSortNotifier.new,
);

class FeedSortNotifier extends Notifier<NoteSort> {
  @override
  NoteSort build() {
    Future.microtask(_loadFromSettings);
    return NoteSort.createdAt;
  }

  Future<void> _loadFromSettings() async {
    final settings = await ref.read(appSettingsStoreProvider).loadSettings();
    if (state != settings.feedSort) {
      state = settings.feedSort;
    }
  }

  Future<void> setSort(NoteSort sort) async {
    if (state == sort) return;
    state = sort;
    final store = ref.read(appSettingsStoreProvider);
    final current = await store.loadSettings();
    await store.saveSettings(current.copyWith(feedSort: sort));
    ref.invalidate(notesListProvider);
  }
}

final outboxCountProvider = FutureProvider<int>((ref) async {
  if (ref.watch(isWebClientProvider)) return 0;
  final service = await ref.watch(notesServiceProvider.future);
  return service.pendingOutboxCount();
});

final pendingSyncNoteIdsProvider = FutureProvider<Set<String>>((ref) async {
  if (ref.watch(isWebClientProvider)) return {};
  final service = await ref.watch(notesServiceProvider.future);
  return service.pendingOutboxNoteIds();
});

final notesListProvider =
    AsyncNotifierProvider<NotesListNotifier, NotesFeedState>(
  NotesListNotifier.new,
);

/// Incremented after local note mutations; watched by [autoSyncOnNotesChangeProvider].
final pendingLocalSyncProvider = StateProvider<int>((ref) => 0);

final searchResultsProvider =
    AsyncNotifierProvider<SearchResultsNotifier, List<NoteSearchHit>>(
  SearchResultsNotifier.new,
);

class NotesListNotifier extends AsyncNotifier<NotesFeedState> {
  @override
  Future<NotesFeedState> build() async {
    final service = await ref.watch(notesServiceProvider.future);
    ref.watch(feedSortProvider);
    ref.listen(feedSortProvider, (previous, next) {
      if (previous != next) ref.invalidateSelf();
    });
    ref.listen(feedModeProvider, (previous, next) {
      if (previous != next) ref.invalidateSelf();
    });
    return _loadInitial(service);
  }

  Future<NotesFeedState> _loadInitial(NotesService service) async {
    if (ref.read(feedModeProvider) == FeedMode.trash) {
      final notes = await service.listTrash();
      return NotesFeedState(notes: notes, hasMoreOlder: false);
    }

    final sort = ref.read(feedSortProvider);
    final total = await service.countActiveNotes();
    final offset = total > NotesFeedState.pageSize
        ? total - NotesFeedState.pageSize
        : 0;
    final notes = await service.listNotesSlice(
      offset: offset,
      limit: NotesFeedState.pageSize,
      sort: sort,
    );
    return NotesFeedState(
      notes: notes,
      offset: offset,
      hasMoreOlder: offset > 0,
    );
  }

  Future<void> reload() async {
    final service = await ref.read(notesServiceProvider.future);
    state = AsyncData(await _loadInitial(service));
    ref.invalidate(outboxCountProvider);
    ref.invalidate(pendingSyncNoteIdsProvider);
  }

  Future<void> loadOlder() async {
    final current = state.valueOrNull;
    if (current == null ||
        !current.hasMoreOlder ||
        current.isLoadingMore ||
        ref.read(feedModeProvider) == FeedMode.trash ||
        current.offset <= 0) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final service = await ref.read(notesServiceProvider.future);
      final sort = ref.read(feedSortProvider);
      final nextOffset = current.offset > NotesFeedState.pageSize
          ? current.offset - NotesFeedState.pageSize
          : 0;
      final take = current.offset - nextOffset;
      final older = await service.listNotesSlice(
        offset: nextOffset,
        limit: take,
        sort: sort,
      );
      state = AsyncData(
        NotesFeedState(
          notes: [...older, ...current.notes],
          offset: nextOffset,
          hasMoreOlder: nextOffset > 0,
        ),
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> createNote({
    String title = '',
    required String markdown,
    List<String> attachmentPaths = const [],
    List<NoteAttachmentBytes> attachmentBytes = const [],
    AttachmentCopyProgressCallback? onAttachmentProgress,
  }) async {
    final service = await ref.read(notesServiceProvider.future);
    await service.createNote(
      title: title,
      markdown: markdown,
      attachmentPaths: attachmentPaths,
      attachmentBytes: attachmentBytes,
      onAttachmentProgress: onAttachmentProgress,
    );
    await _afterLocalMutation();
  }

  Future<void> addAttachment(String noteId, String sourcePath) async {
    final service = await ref.read(notesServiceProvider.future);
    await service.addAttachment(noteId, sourcePath);
    await _afterLocalMutation();
  }

  Future<void> updateNote(String id, {String? title, String? markdown}) async {
    final service = await ref.read(notesServiceProvider.future);
    await service.updateNote(id, title: title, markdown: markdown);
    await _afterLocalMutation();
  }

  Future<void> deleteNote(String id) async {
    final service = await ref.read(notesServiceProvider.future);
    await service.deleteNote(id);
    await _afterLocalMutation();
  }

  Future<void> restoreNote(String id) async {
    final service = await ref.read(notesServiceProvider.future);
    await service.restoreNote(id);
    await _afterLocalMutation();
  }

  Future<void> _afterLocalMutation() async {
    await reload();
    ref.read(pendingLocalSyncProvider.notifier).state++;
  }
}

class SearchResultsNotifier extends AsyncNotifier<List<NoteSearchHit>> {
  @override
  Future<List<NoteSearchHit>> build() async {
    final query = ref.watch(feedSearchQueryProvider);
    if (query.trim().isEmpty) return [];

    final service = await ref.watch(notesServiceProvider.future);
    return service.searchNotes(query.trim());
  }
}
