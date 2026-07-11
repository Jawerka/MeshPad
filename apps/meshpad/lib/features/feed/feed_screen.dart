import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../core/errors/user_messages.dart';
import '../../core/models/notes_feed_state.dart';
import '../../core/providers/feed_ui_providers.dart';
import '../../core/providers/git_sync_providers.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/providers/sync_activity_provider.dart';
import '../../core/sync/sync_run_feedback.dart';
import '../../core/providers/sync_auth_health_provider.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/ui/meshpad_status_hint.dart';
import '../../core/ui/status_hint_provider.dart';
import '../../core/theme/feed_layout.dart';
import '../../core/theme/meshpad_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/desktop_shell.dart';
import '../devices/devices_sheet.dart';
import '../settings/settings_sheet.dart';
import 'feed_composer_section.dart';
import 'note_bubble.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _composerFocusNode = FocusNode();

  @override
  void dispose() {
    _composerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(feedComposerFocusRequestProvider, (previous, next) {
      if (next != previous) {
        _composerFocusNode.requestFocus();
      }
    });
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
                  ? _EmptyFeed(
                      mode: mode,
                      onRefresh: () async {
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
            if (mode == FeedMode.feed)
              FeedComposerSection(focusNode: _composerFocusNode),
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
      _preserveScrollAfterPrepend(
          beforeExtent: beforeExtent, beforePixels: beforePixels);
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
      final result = await ref.read(syncControllerProvider).runSync();
      if (mounted) showSyncRunFeedback(context, result);
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
            key: ValueKey(note.id),
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
                    key: ValueKey(hit.note.id),
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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(feedSearchQueryProvider),
    );
    if (widget.showSearchField) {
      ref.read(feedSearchOpenProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    final open = !ref.read(feedSearchOpenProvider);
    ref.read(feedSearchOpenProvider.notifier).state = open;
    if (!open) {
      _searchController.clear();
      ref.read(feedSearchQueryProvider.notifier).state = '';
      ref.invalidate(searchResultsProvider);
    }
  }

  void _onSearchChanged(String value) {
    ref.read(feedSearchQueryProvider.notifier).state = value;
    ref.invalidate(searchResultsProvider);
  }

  Future<void> _runHeaderSync(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(syncControllerProvider).runSync();
    if (context.mounted) {
      showSyncRunFeedback(context, result);
    }
  }

  Future<void> _confirmEmptyTrash(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trashEmptyTitle),
        content: Text(l10n.trashEmptyBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.trashEmpty),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final purged = await ref.read(notesListProvider.notifier).emptyTrash();
    if (!context.mounted) return;
    showMeshPadHint(
      context,
      l10n.trashEmptyDone(purged),
      severity: StatusHintSeverity.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchOpen = ref.watch(feedSearchOpenProvider);
    final isTrash = widget.mode == FeedMode.trash;
    final isWeb = ref.watch(isWebClientProvider);
    final outboxAsync = ref.watch(outboxCountProvider);
    final outboxCount = outboxAsync.valueOrNull ?? 0;
    final syncActivity = ref.watch(syncActivityProvider);
    final signingKeyResetAsync = ref.watch(syncAuthHealthProvider);
    final trustedAsync = ref.watch(trustedDevicesProvider);
    final needsRePair = signingKeyResetAsync.valueOrNull == true ||
        (trustedAsync.valueOrNull?.any((d) => d.needsRePairing) ?? false);
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final compact = isCompactFeedLayout(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: MeshPadColors.headerHeight,
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
          decoration: BoxDecoration(
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
              if (isTrash)
                Text(
                  'Корзина',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              if (isTrash && widget.count > 0) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_forever_outlined),
                  tooltip: AppLocalizations.of(context).trashEmpty,
                  onPressed: () => _confirmEmptyTrash(context),
                ),
              ],
              const Spacer(),
              if (!isTrash) ...[
                if (!compact) const _FeedSortButton(),
                if (!isWeb)
                  _HeaderSyncButton(
                    activity: syncActivity,
                    outboxCount: outboxCount,
                    needsRePair: needsRePair,
                    rePairTooltip:
                        l10n?.syncNeedsRePairTooltip ?? 'Re-pairing required',
                    onPressed: () => unawaited(_runHeaderSync(context, ref)),
                  ),
                if (!isWeb && (Platform.isWindows || Platform.isLinux)) ...[
                  IconButton(
                    icon: const Icon(Icons.cloud_download_outlined),
                    tooltip: 'Git pull',
                    onPressed: () async {
                      final result =
                          await ref.read(gitSyncControllerProvider).pull();
                      if (!context.mounted) return;
                      showMeshPadHint(
                        context,
                        result.ok
                            ? 'Git: обновлено'
                            : (result.message ?? 'Git pull failed'),
                        severity: result.ok
                            ? StatusHintSeverity.success
                            : StatusHintSeverity.error,
                      );
                      if (result.ok) {
                        ref.invalidate(notesListProvider);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    tooltip: 'Git push',
                    onPressed: () async {
                      final result =
                          await ref.read(gitSyncControllerProvider).push();
                      if (!context.mounted) return;
                      showMeshPadHint(
                        context,
                        result.ok
                            ? 'Git: отправлено'
                            : (result.message ?? 'Git push failed'),
                        severity: result.ok
                            ? StatusHintSeverity.success
                            : StatusHintSeverity.error,
                      );
                    },
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.search),
                  color: searchOpen ? MeshPadColors.primary : null,
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
                if (compact || DesktopShell.isSupported)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Корзина',
                    onPressed: () {
                      ref.read(feedModeProvider.notifier).state =
                          FeedMode.trash;
                      ref.invalidate(notesListProvider);
                    },
                  ),
              ],
              if (!isTrash || widget.count > 0)
                Text('${widget.count}',
                    style: Theme.of(context).textTheme.labelSmall),
              SizedBox(width: compact ? 4 : 12),
            ],
          ),
        ),
        if (searchOpen)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: MeshPadColors.backgroundElevated,
              border: Border(bottom: BorderSide(color: MeshPadColors.border)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: MeshPadColors.chatMaxWidth),
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

String formatNoteDate(DateTime dt) {
  return DateFormat('HH:mm dd.MM.yy', 'ru').format(dt.toLocal());
}

class _FeedSortButton extends ConsumerWidget {
  const _FeedSortButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(feedSortProvider);
    final isUpdated = sort == NoteSort.updatedAt;
    return IconButton(
      tooltip:
          isUpdated ? 'Сортировка: по изменению' : 'Сортировка: по созданию',
      icon: Icon(
        isUpdated ? Icons.edit_calendar_outlined : Icons.schedule_outlined,
        color: isUpdated ? MeshPadColors.primary : null,
      ),
      onPressed: () {
        ref.read(feedSortProvider.notifier).setSort(
              isUpdated ? NoteSort.createdAt : NoteSort.updatedAt,
            );
      },
    );
  }
}

class _HeaderSyncButton extends StatefulWidget {
  const _HeaderSyncButton({
    required this.activity,
    required this.outboxCount,
    required this.needsRePair,
    required this.rePairTooltip,
    required this.onPressed,
  });

  final SyncActivity activity;
  final int outboxCount;
  final bool needsRePair;
  final String rePairTooltip;
  final VoidCallback onPressed;

  @override
  State<_HeaderSyncButton> createState() => _HeaderSyncButtonState();
}

class _HeaderSyncButtonState extends State<_HeaderSyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  late final Animation<double> _turns;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _turns = Tween<double>(begin: 0, end: -1).animate(_spin);
    _syncSpin(widget.activity.active);
  }

  @override
  void didUpdateWidget(covariant _HeaderSyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin(widget.activity.active);
  }

  void _syncSpin(bool active) {
    if (active) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
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
        ? MeshPadColors.primary
        : widget.needsRePair
            ? MeshPadColors.danger
            : null;

    return IconButton(
      tooltip: active
          ? 'Синхронизация…'
          : widget.needsRePair
              ? widget.rePairTooltip
              : 'Синхронизировать',
      onPressed: active ? null : widget.onPressed,
      icon: Badge(
        isLabelVisible: widget.outboxCount > 0 || widget.needsRePair,
        label: widget.outboxCount > 0
            ? Text('${widget.outboxCount}')
            : widget.needsRePair
                ? const Text('!')
                : null,
        backgroundColor: widget.needsRePair ? MeshPadColors.danger : null,
        child: RotationTransition(
          turns: active ? _turns : const AlwaysStoppedAnimation(0),
          child: Icon(Icons.sync, color: color),
        ),
      ),
    );
  }
}
