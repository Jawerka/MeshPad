import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/notes_providers.dart';
import '../../core/theme/meshpad_colors.dart';
import 'note_bubble.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(feedModeProvider);
    final notesAsync = ref.watch(notesListProvider);

    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
      data: (notes) {
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

class _FeedHeader extends ConsumerWidget {
  const _FeedHeader({required this.mode, required this.count});

  final FeedMode mode;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTrash = mode == FeedMode.trash;

    return Container(
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
          Text('$count', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(width: 12),
        ],
      ),
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
  var _saving = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(notesListProvider.notifier).createNote(markdown: body);
      _bodyController.clear();
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
        ),
      ),
    );
  }
}

String formatNoteDate(DateTime dt) {
  return DateFormat('d MMM yyyy, HH:mm', 'ru').format(dt.toLocal());
}
