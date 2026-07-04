import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meshpad_p2p/meshpad_p2p.dart';

import '../../core/providers/git_sync_providers.dart';
import '../../core/providers/network_sync_coordinator.dart';
import '../../core/providers/notes_providers.dart';
import '../../core/providers/discovery_providers.dart';
import '../../core/providers/settings_providers.dart';
import '../../core/providers/sync_loop_provider.dart';
import '../../core/providers/sync_providers.dart';
import '../../core/providers/web_feed_events_provider.dart';
import '../../core/sync/local_author_labels.dart';
import '../../core/theme/meshpad_colors.dart';
import '../../platform/desktop_shell.dart';
import '../feed/feed_desktop_shortcuts.dart';
import '../feed/feed_screen.dart';
import '../settings/settings_sheet.dart';
import '../../core/providers/feed_ui_providers.dart';

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
        try {
          await ref.read(appSettingsProvider.future);
          await ref.read(localIdentityProvider.future);
          ref.read(syncLoopProvider).start();
          await ref.read(networkSyncCoordinatorProvider).start();
          await ref.read(discoveryServiceProvider).start();
          await ref.read(gitSyncLoopProvider).start();
        } catch (e, st) {
          MeshPadLog.warn('discovery', 'LAN transport startup failed: $e');
          MeshPadLog.warn('discovery', '$st');
        }
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
          ref.invalidate(outboxCountProvider);
        } catch (e, st) {
          MeshPadLog.warn('sync', 'startup outbox cleanup failed: $e');
          MeshPadLog.warn('sync', '$st');
        }
        try {
          await ref.read(settingsControllerProvider).runAutoBackupIfDue();
        } catch (e, st) {
          MeshPadLog.warn('backup', 'scheduled backup failed: $e');
          MeshPadLog.warn('backup', '$st');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(autoSyncOnNotesChangeProvider);
    ref.watch(networkSyncCoordinatorProvider);
    ref.watch(webFeedEventsProvider);
    ref.listen(feedSettingsOpenRequestProvider, (previous, next) {
      if (next != previous && mounted) {
        SettingsSheet.show(context);
      }
    });
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
              child: const FeedDesktopShortcuts(
                child: FeedScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
