import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/notes_providers.dart';
import '../../core/theme/meshpad_colors.dart';
import '../feed/feed_screen.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(feedModeProvider);
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          const FeedScreen(),
          if (mode == FeedMode.feed)
            Positioned(
              top: topPadding + MeshPadColors.headerHeight + 12,
              right: 16,
              child: _TrashFab(
                onPressed: () {
                  ref.read(feedModeProvider.notifier).state = FeedMode.trash;
                  ref.invalidate(notesListProvider);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TrashFab extends StatelessWidget {
  const _TrashFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black54,
      color: MeshPadColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
        side: const BorderSide(color: MeshPadColors.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
        child: Tooltip(
          message: 'Корзина',
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
