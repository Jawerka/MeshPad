import 'package:flutter/material.dart';

import 'meshpad_palette.dart';

/// Design tokens from ref/chat-layout.css; colors follow [MeshPadPalette.active].
abstract final class MeshPadColors {
  static MeshPadPalette _palette = MeshPadPalette.dark;

  static MeshPadPalette get palette => _palette;

  static void applyPalette(MeshPadPalette palette) {
    _palette = palette;
  }

  static Color get background => _palette.background;
  static Color get backgroundElevated => _palette.backgroundElevated;
  static Color get surface => _palette.surface;
  static Color get border => _palette.border;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textMuted => _palette.textMuted;
  static Color get primary => _palette.primary;
  static Color get primaryHover => _palette.primaryHover;
  static Color get danger => _palette.danger;
  static Color get success => _palette.success;

  static const sidebarWidth = 280.0;
  static const headerHeight = 52.0;
  static const chatMaxWidth = 820.0;
  static const composerMaxWidth = 640.0;
  static const radiusMd = 12.0;
  static const radiusLg = 18.0;
}
