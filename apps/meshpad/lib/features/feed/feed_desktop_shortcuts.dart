import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/feed_ui_providers.dart';
import '../../platform/desktop_shell.dart';

class FeedNewNoteIntent extends Intent {
  const FeedNewNoteIntent();
}

class FeedToggleSearchIntent extends Intent {
  const FeedToggleSearchIntent();
}

class FeedOpenSettingsIntent extends Intent {
  const FeedOpenSettingsIntent();
}

/// Desktop hotkeys: Ctrl+N, F, K (PLAN §11.9.4).
class FeedDesktopShortcuts extends ConsumerWidget {
  const FeedDesktopShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DesktopShell.isSupported) return child;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const FeedNewNoteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const FeedToggleSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const FeedOpenSettingsIntent(),
      },
      child: Actions(
        actions: {
          FeedNewNoteIntent: CallbackAction<FeedNewNoteIntent>(
            onInvoke: (_) {
              ref.read(feedComposerFocusRequestProvider.notifier).state++;
              return null;
            },
          ),
          FeedToggleSearchIntent: CallbackAction<FeedToggleSearchIntent>(
            onInvoke: (_) {
              final open = ref.read(feedSearchOpenProvider);
              ref.read(feedSearchOpenProvider.notifier).state = !open;
              return null;
            },
          ),
          FeedOpenSettingsIntent: CallbackAction<FeedOpenSettingsIntent>(
            onInvoke: (_) {
              ref.read(feedSettingsOpenRequestProvider.notifier).state++;
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
