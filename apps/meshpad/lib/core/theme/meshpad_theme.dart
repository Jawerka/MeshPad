import 'package:flutter/material.dart';

import 'meshpad_colors.dart';
import 'meshpad_palette.dart';

abstract final class MeshPadTheme {
  static ThemeData forPalette(MeshPadPalette palette) {
    final isDark = palette == MeshPadPalette.dark ||
        (palette.background.computeLuminance() < 0.5);

    final scheme = isDark
        ? ColorScheme.dark(
            surface: palette.background,
            primary: palette.primary,
            onPrimary: Colors.white,
            error: palette.danger,
          )
        : ColorScheme.light(
            surface: palette.background,
            primary: palette.primary,
            onPrimary: Colors.white,
            error: palette.danger,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      dividerColor: palette.border,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.backgroundElevated,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshPadColors.radiusLg),
          side: BorderSide(color: palette.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.backgroundElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: palette.textMuted),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
        titleMedium: TextStyle(
          color: palette.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        labelSmall: TextStyle(color: palette.textMuted, fontSize: 12),
      ),
      iconTheme: IconThemeData(color: palette.textMuted, size: 20),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData dark() => forPalette(MeshPadPalette.dark);

  static ThemeData light() => forPalette(MeshPadPalette.light);
}
