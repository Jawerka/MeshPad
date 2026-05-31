import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/notes_providers.dart';
import '../../core/providers/discovery_providers.dart';
import '../../core/providers/sync_loop_provider.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/sync/local_author_labels.dart';
import '../../core/theme/feed_layout.dart';
import '../../core/theme/meshpad_colors.dart';
import '../../platform/desktop_shell.dart';
import '../feed/feed_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(isWebClientProvider)) {
        ref.read(syncLoopProvider).start();
        ref.read(discoveryServiceProvider).start();
        if (DesktopShell.isSupported) {
          DesktopShell.instance.onSync =
              () => ref.read(syncControllerProvider).runSync();
        }
        try {
          final repo = await ref.read(noteRepositoryProvider.future);
          final identity = await ref.read(localIdentityProvider.future);
          await repo.purgeMisfiledRemoteOutbox(
            localAuthorLabels: localAuthorLabels(identity.displayName),
          );
          await repo.purgeExhaustedOutboxEntries(maxRetries: 5);
          ref.invalidate(outboxCountProvider);
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(feedModeProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: MeshPadColors.backgroundElevated,
      body: Column(
        children: [
          ColoredBox(
            color: MeshPadColors.backgroundElevated,
            child: SizedBox(height: topInset),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Stack(
                children: [
                  const FeedScreen(),
                  if (mode == FeedMode.feed && !isCompactFeedLayout(context))
                    Positioned(
                      top: MeshPadColors.headerHeight + 12,
                      right: 16,
                      child: _TrashFab(
                        onPressed: () {
                          ref.read(feedModeProvider.notifier).state =
                              FeedMode.trash;
                          ref.invalidate(notesListProvider);
                        },
                      ),
                    ),
                ],
              ),
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
