import 'package:flutter/material.dart';

/// Semantic color tokens for MeshPad UI (dark / light).
class MeshPadPalette {
  const MeshPadPalette({
    required this.background,
    required this.backgroundElevated,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.primary,
    required this.primaryHover,
    required this.danger,
    required this.success,
  });

  final Color background;
  final Color backgroundElevated;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color primary;
  final Color primaryHover;
  final Color danger;
  final Color success;

  static const dark = MeshPadPalette(
    background: Color(0xFF0f1419),
    backgroundElevated: Color(0xFF151b23),
    surface: Color(0xFF1c2430),
    border: Color(0xFF2d3748),
    textPrimary: Color(0xFFe7ecf3),
    textMuted: Color(0xFF8b98a8),
    primary: Color(0xFF6b9fff),
    primaryHover: Color(0xFF85b1ff),
    danger: Color(0xFFf85149),
    success: Color(0xFF3fb950),
  );

  static const light = MeshPadPalette(
    background: Color(0xFFf4f6f9),
    backgroundElevated: Color(0xFFffffff),
    surface: Color(0xFFeef1f6),
    border: Color(0xFFd5dde8),
    textPrimary: Color(0xFF1a2332),
    textMuted: Color(0xFF5c6b7f),
    primary: Color(0xFF3d7bf5),
    primaryHover: Color(0xFF2563eb),
    danger: Color(0xFFdc2626),
    success: Color(0xFF16a34a),
  );

  static MeshPadPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
