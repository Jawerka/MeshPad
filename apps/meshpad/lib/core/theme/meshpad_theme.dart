import 'package:flutter/material.dart';

import 'meshpad_colors.dart';

abstract final class MeshPadTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      surface: MeshPadColors.background,
      primary: MeshPadColors.primary,
      onPrimary: Colors.white,
      error: MeshPadColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: MeshPadColors.background,
      dividerColor: MeshPadColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: MeshPadColors.backgroundElevated,
        foregroundColor: MeshPadColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: MeshPadColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MeshPadColors.radiusLg),
          side: const BorderSide(color: MeshPadColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MeshPadColors.backgroundElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
          borderSide: const BorderSide(color: MeshPadColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
          borderSide: const BorderSide(color: MeshPadColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MeshPadColors.radiusMd),
          borderSide: const BorderSide(color: MeshPadColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: MeshPadColors.textMuted),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          color: MeshPadColors.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
        titleMedium: TextStyle(
          color: MeshPadColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        labelSmall: TextStyle(color: MeshPadColors.textMuted, fontSize: 12),
      ),
      iconTheme: const IconThemeData(color: MeshPadColors.textMuted, size: 20),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MeshPadColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
