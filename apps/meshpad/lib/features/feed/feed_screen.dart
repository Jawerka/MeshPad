import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../core/errors/user_messages.dart';
import '../../core/models/notes_feed_state.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/providers/sync_activity_provider.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/services/notes_service.dart';
import '../../core/theme/feed_layout.dart';
import '../../core/theme/meshpad_colors.dart';
import '../../platform/desktop_shell.dart';
import '../devices/devices_sheet.dart';
import '../settings/settings_sheet.dart';
import 'composer_drop_target.dart';
import 'note_bubble.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(feedModeProvider);
    final searchQuery = ref.watch(feedSearchQueryProvider);
    final isSearching = mode == FeedMode.feed && searchQuery.trim().isNotEmpty;

    if (isSearching) {
      return _SearchFeed(searchQuery: searchQuery.trim());
    }

    final notesAsync = ref.watch(notesListProvider);

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(userFacingError(e))),
      data: (feed) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FeedHeader(mode: mode, count: feed.notes.length),
            Expanded(
              child: feed.notes.isEmpty
                  ? _EmptyFeed(mode: mode, onRefresh: () async {
                      if (!ref.read(isWebClientProvider)) {
                        await ref.read(syncControllerProvider).runSync();
                      }
                      await ref.read(notesListProvider.notifier).reload();
                    })
                  : _PaginatedFeedList(
                      feed: feed,
                      mode: mode,
                    ),
            ),
            if (mode == FeedMode.feed) const _ComposerSection(),
          ],
        );
      },
    );
  }
}

class _PaginatedFeedList extends ConsumerStatefulWidget {
  const _PaginatedFeedList({
    required this.feed,
    required this.mode,
  });

  final NotesFeedState feed;
  final FeedMode mode;

  @override
  ConsumerState<_PaginatedFeedList> createState() => _PaginatedFeedListState();
}

class _PaginatedFeedListState extends ConsumerState<_PaginatedFeedList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PaginatedFeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feed.notes.length != oldWidget.feed.notes.length &&
        !widget.feed.isLoadingMore &&
        widget.feed.notes.length > oldWidget.feed.notes.length &&
        widget.feed.notes.last.id != oldWidget.feed.notes.last.id) {
      _scrollToLatest();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || widget.mode != FeedMode.feed) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels > 240) return;

    final feed = ref.read(notesListProvider).valueOrNull;
    if (feed == null || !feed.hasMoreOlder || feed.isLoadingMore) return;

    final beforeExtent = position.maxScrollExtent;
    final beforePixels = position.pixels;

    ref.read(notesListProvider.notifier).loadOlder().then((_) {
      if (!mounted) return;
      _preserveScrollAfterPrepend(beforeExtent: beforeExtent, beforePixels: beforePixels);
    });
  }

  void _preserveScrollAfterPrepend({
    required double beforeExtent,
    required double beforePixels,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final delta = _scrollController.position.maxScrollExtent - beforeExtent;
      if (delta > 0) {
        _scrollController.jumpTo(beforePixels + delta);
      }
    });
  }

  void _scrollToLatest() {
    if (widget.mode != FeedMode.feed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  Future<void> _refreshFeed() async {
    if (!ref.read(isWebClientProvider)) {
      await ref.read(syncControllerProvider).runSync();
    }
    await ref.read(notesListProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.feed.notes;
    final headerCount = widget.feed.isLoadingMore ? 1 : 0;
    final compact = isCompactFeedLayout(context);
    final bubbleMaxWidth = feedBubbleMaxWidth(context);

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 16, compact ? 8 : 16, 8),
        itemCount: notes.length + headerCount,
        itemBuilder: (context, index) {
          if (headerCount > 0 && index == notes.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final note = notes[notes.length - 1 - index];
          return Padding(
            padding: EdgeInsets.only(bottom: compact ? 8 : 12),
            child: compact
                ? NoteBubble(
                    note: note,
                    isTrash: widget.mode == FeedMode.trash,
                  )
                : Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                      child: NoteBubble(
                        note: note,
                        isTrash: widget.mode == FeedMode.trash,
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _SearchFeed extends ConsumerWidget {
  const _SearchFeed({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FeedHeader(mode: FeedMode.feed, count: 0, showSearchField: true),
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(userFacingError(e))),
            data: (hits) {
              if (hits.isEmpty) {
                return Center(
                  child: Text(
                    'Ничего не найдено по запросу «$searchQuery».',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MeshPadColors.textMuted,
                        ),
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  isCompactFeedLayout(context) ? 8 : 16,
                  8,
                  isCompactFeedLayout(context) ? 8 : 16,
                  16,
                ),
                itemCount: hits.length,
                itemBuilder: (context, index) {
                  final hit = hits[index];
                  final compact = isCompactFeedLayout(context);
                  final bubble = NoteBubble(note: hit.note);
                  return Padding(
                    padding: EdgeInsets.only(bottom: compact ? 8 : 12),
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hit.snippet.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 6, left: 4),
                                  child: Text(
                                    hit.snippet,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                              bubble,
                            ],
                          )
                        : Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: feedBubbleMaxWidth(context),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hit.snippet.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 6,
                                        left: 4,
                                      ),
                                      child: Text(
                                        hit.snippet,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ),
                                  bubble,
                                ],
                              ),
                            ),
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeedHeader extends ConsumerStatefulWidget {
  const _FeedHeader({
    required this.mode,
    required this.count,
    this.showSearchField = false,
  });

  final FeedMode mode;
  final int count;
  final bool showSearchField;

  @override
  ConsumerState<_FeedHeader> createState() => _FeedHeaderState();
}

class _FeedHeaderState extends ConsumerState<_FeedHeader> {
  late final TextEditingController _searchController;
  var _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(feedSearchQueryProvider),
    );
    _searchOpen = widget.showSearchField;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        ref.read(feedSearchQueryProvider.notifier).state = '';
        ref.invalidate(searchResultsProvider);
      }
    });
  }

  void _onSearchChanged(String value) {
    ref.read(feedSearchQueryProvider.notifier).state = value;
    ref.invalidate(searchResultsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isTrash = widget.mode == FeedMode.trash;
    final isWeb = ref.watch(isWebClientProvider);
    final outboxAsync = ref.watch(outboxCountProvider);
    final outboxCount = outboxAsync.valueOrNull ?? 0;
    final syncActivity = ref.watch(syncActivityProvider);
    final compact = isCompactFeedLayout(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: MeshPadColors.headerHeight,
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
          decoration: const BoxDecoration(
            color: MeshPadColors.backgroundElevated,
            border: Border(bottom: BorderSide(color: MeshPadColors.border)),
          ),
          child: Row(
            children: [
              if (isTrash)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'К ленте',
                  onPressed: () {
                    ref.read(feedModeProvider.notifier).state = FeedMode.feed;
                    ref.invalidate(notesListProvider);
                  },
                )
              else
                const SizedBox(width: 8),
              Text(
                isTrash ? 'Корзина' : 'MeshPad',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (!isTrash) ...[
                if (!isWeb && DesktopShell.isSupported)
                  _HeaderSyncButton(
                    activity: syncActivity,
                    outboxCount: outboxCount,
                    onPressed: () =>
                        ref.read(syncControllerProvider).runSync(),
                  )
                else if (!isWeb && (syncActivity.active || outboxCount > 0))
                  _SyncQueueIndicator(
                    activity: syncActivity,
                    outboxCount: outboxCount,
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  color: _searchOpen ? MeshPadColors.primary : null,
                  tooltip: 'Поиск',
                  onPressed: _toggleSearch,
                ),
                if (!isWeb)
                  IconButton(
                    icon: const Icon(Icons.devices),
                    tooltip: 'Устройства',
                    onPressed: () => DevicesSheet.show(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Настройки',
                  onPressed: () => SettingsSheet.show(context),
                ),
                if (compact)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Корзина',
                    onPressed: () {
                      ref.read(feedModeProvider.notifier).state = FeedMode.trash;
                      ref.invalidate(notesListProvider);
                    },
                  ),
              ],
              if (!isTrash || widget.count > 0)
                Text('${widget.count}', style: Theme.of(context).textTheme.labelSmall),
              SizedBox(width: compact ? 4 : 12),
            ],
          ),
        ),
        if (_searchOpen)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: MeshPadColors.backgroundElevated,
              border: Border(bottom: BorderSide(color: MeshPadColors.border)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: MeshPadColors.chatMaxWidth),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Поиск по тексту заметок…',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.mode, required this.onRefresh});

  final FeedMode mode;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = mode == FeedMode.feed
        ? 'Нет заметок.\nНапишите первую в поле внизу.'
        : 'Корзина пуста.\nУдалённые заметки хранятся 7 дней.';
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.35),
          Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MeshPadColors.textMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerSection extends ConsumerStatefulWidget {
  const _ComposerSection();

  @override
  ConsumerState<_ComposerSection> createState() => _ComposerSectionState();
}

class _ComposerSectionState extends ConsumerState<_ComposerSection> {
  final _bodyController = TextEditingController();
  final _pendingFiles = <PlatformFile>[];
  var _saving = false;
  AttachmentCopyProgress? _copyProgress;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return;
    _addPendingFiles(result.files);
  }

  void _addPendingFiles(List<PlatformFile> incoming) {
    setState(() {
      for (final file in incoming) {
        if (kIsWeb && file.bytes == null) continue;
        if (!kIsWeb && file.path == null) continue;
        final duplicate = _pendingFiles.any(
          (existing) =>
              existing.name == file.name && existing.size == file.size,
        );
        if (!duplicate) _pendingFiles.add(file);
      }
    });
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty && _pendingFiles.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _copyProgress = null;
    });
    try {
      await ref.read(notesListProvider.notifier).createNote(
            markdown: body,
            attachmentPaths: kIsWeb
                ? const []
                : _pendingFiles.map((file) => file.path!).toList(),
            attachmentBytes: kIsWeb
                ? [
                    for (final file in _pendingFiles)
                      NoteAttachmentBytes(
                        name: file.name,
                        bytes: file.bytes!,
                      ),
                  ]
                : const [],
            onAttachmentProgress: _pendingFiles.isEmpty
                ? null
                : (progress) {
                    if (mounted) setState(() => _copyProgress = progress);
                  },
          );
      _bodyController.clear();
      setState(() {
        _pendingFiles.clear();
        _copyProgress = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _copyProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompactFeedLayout(context);
    final composer = _buildComposer(context);
    return ComposerDropTarget(
      enabled: !_saving,
      onFilesDropped: _addPendingFiles,
      child: Container(
        padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 12, compact ? 8 : 16, 16),
        decoration: const BoxDecoration(
          color: MeshPadColors.backgroundElevated,
          border: Border(top: BorderSide(color: MeshPadColors.border)),
        ),
        child: compact
            ? composer
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: MeshPadColors.composerMaxWidth,
                  ),
                  child: composer,
                ),
              ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_copyProgress != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _copyProgress!.fileCount > 1
                      ? 'Копирование ${_copyProgress!.fileName} '
                          '(${_copyProgress!.fileIndex}/${_copyProgress!.fileCount})'
                      : 'Копирование ${_copyProgress!.fileName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MeshPadColors.textMuted,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _copyProgress!.isIndeterminate
                      ? null
                      : _copyProgress!.fraction,
                  minHeight: 3,
                ),
              ],
            ),
          ),
        if (_pendingFiles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final file in _pendingFiles)
                  _PendingAttachmentChip(
                    name: file.name,
                    onRemove: () => setState(() => _pendingFiles.remove(file)),
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _saving ? null : _pickAttachments,
              icon: const Icon(Icons.attach_file),
              tooltip: 'Прикрепить файл',
            ),
            Expanded(
              child: TextField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  hintText: 'Новая заметка…',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                minLines: 1,
                maxLines: 10,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({required this.name, required this.onRemove});

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = isImageAttachment(
      AttachmentMeta(name: name, size: 0, mime: mimeFromFileName(name)),
    );

    return InputChip(
      label: Text(name, overflow: TextOverflow.ellipsis),
      avatar: Icon(
        isImage ? Icons.image_outlined : Icons.insert_drive_file,
        size: 18,
      ),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
    );
  }
}

String formatNoteDate(DateTime dt) {
  return DateFormat('HH:mm dd.MM.yy', 'ru').format(dt.toLocal());
}

class _HeaderSyncButton extends StatelessWidget {
  const _HeaderSyncButton({
    required this.activity,
    required this.outboxCount,
    required this.onPressed,
  });

  final SyncActivity activity;
  final int outboxCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = activity.active;
    final color = active
        ? Theme.of(context).colorScheme.primary
        : null;

    return IconButton(
      tooltip: active ? 'Синхронизация…' : 'Синхронизировать',
      onPressed: active ? null : onPressed,
      icon: Badge(
        isLabelVisible: outboxCount > 0,
        label: Text('$outboxCount'),
        child: active
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(Icons.sync, color: color),
      ),
    );
  }
}

class _SyncQueueIndicator extends StatefulWidget {
  const _SyncQueueIndicator({
    required this.activity,
    required this.outboxCount,
  });

  final SyncActivity activity;
  final int outboxCount;

  @override
  State<_SyncQueueIndicator> createState() => _SyncQueueIndicatorState();
}

class _SyncQueueIndicatorState extends State<_SyncQueueIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didUpdateWidget(covariant _SyncQueueIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activity.active && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.activity.active) {
      _spin.stop();
      _spin.reset();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activity.active;
    final color = active
        ? Theme.of(context).colorScheme.primary
        : MeshPadColors.textMuted;
    if (active && !_spin.isAnimating) {
      _spin.repeat();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: active ? _spin : const AlwaysStoppedAnimation(0),
            child: Icon(Icons.sync, size: 16, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.outboxCount}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (active && widget.activity.progress != null) ...[
            const SizedBox(width: 6),
            SizedBox(
              width: 48,
              child: LinearProgressIndicator(
                value: widget.activity.progress,
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
