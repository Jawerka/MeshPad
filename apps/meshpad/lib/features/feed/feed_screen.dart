import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meshpad_core/meshpad_core.dart';

import '../../core/providers/notes_providers.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/theme/meshpad_colors.dart';
import '../devices/devices_sheet.dart';
import '../settings/settings_sheet.dart';
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
    final syncStatusesAsync = ref.watch(noteSyncStatusesProvider);

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (notes) {
        final syncMap = syncStatusesAsync.valueOrNull ?? const {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FeedHeader(mode: mode, count: notes.length),
            Expanded(
              child: notes.isEmpty
                  ? _EmptyFeed(mode: mode)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: MeshPadColors.chatMaxWidth,
                              ),
                              child: NoteBubble(
                                note: note,
                                isTrash: mode == FeedMode.trash,
                                syncStatus: syncMap[note.id] ??
                                    NoteSyncStatus.synced,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (mode == FeedMode.feed) const _ComposerSection(),
          ],
        );
      },
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
            error: (e, _) => Center(child: Text('Ошибка: $e')),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: hits.length,
                itemBuilder: (context, index) {
                  final hit = hits[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: MeshPadColors.chatMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hit.snippet.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6, left: 4),
                                child: Text(
                                  hit.snippet,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            NoteBubble(note: hit.note),
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
    final outboxAsync = ref.watch(outboxCountProvider);
    final outboxCount = outboxAsync.valueOrNull ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: MeshPadColors.headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
                if (outboxCount > 0)
                  Tooltip(
                    message: 'В очереди синхронизации: $outboxCount',
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.sync,
                            size: 16,
                            color: MeshPadColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$outboxCount',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.search),
                  color: _searchOpen ? MeshPadColors.primary : null,
                  tooltip: 'Поиск',
                  onPressed: _toggleSearch,
                ),
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
              ],
              if (!isTrash || widget.count > 0)
                Text('${widget.count}', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 12),
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
  const _EmptyFeed({required this.mode});

  final FeedMode mode;

  @override
  Widget build(BuildContext context) {
    final text = mode == FeedMode.feed
        ? 'Нет заметок.\nНапишите первую в поле внизу.'
        : 'Корзина пуста.\nУдалённые заметки хранятся 7 дней.';
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MeshPadColors.textMuted,
            ),
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
  final _pendingPaths = <String>[];
  var _saving = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        final path = file.path;
        if (path != null && !_pendingPaths.contains(path)) {
          _pendingPaths.add(path);
        }
      }
    });
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty && _pendingPaths.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(notesListProvider.notifier).createNote(
            markdown: body,
            attachmentPaths: List.of(_pendingPaths),
          );
      _bodyController.clear();
      setState(_pendingPaths.clear);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: MeshPadColors.backgroundElevated,
        border: Border(top: BorderSide(color: MeshPadColors.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: MeshPadColors.composerMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_pendingPaths.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final path in _pendingPaths)
                        _PendingAttachmentChip(
                          path: path,
                          onRemove: () => setState(() => _pendingPaths.remove(path)),
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
          ),
        ),
      ),
    );
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({required this.path, required this.onRemove});

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = path.split(Platform.pathSeparator).last;
    final isImage = isImageAttachment(
      AttachmentMeta(name: name, size: 0, mime: mimeFromFileName(name)),
    );

    return InputChip(
      label: Text(name, overflow: TextOverflow.ellipsis),
      avatar: isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(File(path), width: 24, height: 24, fit: BoxFit.cover),
            )
          : const Icon(Icons.insert_drive_file, size: 18),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
    );
  }
}

String formatNoteDate(DateTime dt) {
  return DateFormat('d MMM yyyy, HH:mm', 'ru').format(dt.toLocal());
}
