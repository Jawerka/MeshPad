import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/notes_providers.dart';
import '../../core/providers/discovery_providers.dart';
import '../../core/providers/sync_loop_provider.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/sync/local_author_labels.dart';
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
    ref.watch(autoSyncOnNotesChangeProvider);
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
              child: const FeedScreen(),
            ),
          ),
        ],
      ),
    );
  }
}
