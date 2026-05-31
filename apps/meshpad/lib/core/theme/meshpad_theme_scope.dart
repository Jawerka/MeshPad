import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notes_providers.dart';
import '../storage/app_settings.dart';
import 'meshpad_colors.dart';
import 'meshpad_palette.dart';
import 'meshpad_theme.dart';

Brightness effectiveBrightness({
  required AppThemeMode mode,
  required Brightness platformBrightness,
}) {
  return switch (mode) {
    AppThemeMode.dark => Brightness.dark,
    AppThemeMode.light => Brightness.light,
    AppThemeMode.system => platformBrightness,
  };
}

ThemeMode toMaterialThemeMode(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.system => ThemeMode.system,
  };
}

/// Resolves palette + Material theme from persisted settings and OS brightness.
class MeshPadThemeScope extends ConsumerWidget {
  const MeshPadThemeScope({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    return settings.when(
      loading: () {
        MeshPadColors.applyPalette(MeshPadPalette.dark);
        return Theme(
          data: MeshPadTheme.dark(),
          child: child,
        );
      },
      error: (_, __) {
        MeshPadColors.applyPalette(MeshPadPalette.dark);
        return Theme(
          data: MeshPadTheme.dark(),
          child: child,
        );
      },
      data: (appSettings) {
        final brightness = effectiveBrightness(
          mode: appSettings.themeMode,
          platformBrightness: platformBrightness,
        );
        final palette = MeshPadPalette.forBrightness(brightness);
        MeshPadColors.applyPalette(palette);
        return Theme(
          data: MeshPadTheme.forPalette(palette),
          child: child,
        );
      },
    );
  }
}
