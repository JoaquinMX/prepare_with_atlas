import 'package:flutter/material.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';

/// Builds the Atlas [ThemeData] variants from design tokens.
abstract final class AtlasTheme {
  /// The light theme for PrepareWithAtlas.
  static ThemeData get light {
    const borderRadius = BorderRadius.all(Radius.circular(8));
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: AtlasColors.accent,
        onSurface: Color(0xFF0B0D10),
        outline: Color(0xFFD1D5DB),
        error: AtlasColors.danger,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AtlasColors.accent,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0B0D10),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          shape: const RoundedRectangleBorder(borderRadius: borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: Color(0xFFD1D5DB)),
        ),
        hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
        space: 0,
      ),
    );
  }

  /// The primary dark theme for PrepareWithAtlas.
  static ThemeData get dark {
    const borderRadius = BorderRadius.all(Radius.circular(8));
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AtlasColors.background,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        surface: AtlasColors.surface,
        primary: AtlasColors.accent,
        onPrimary: Colors.white,
        onSurface: AtlasColors.textPrimary,
        outline: AtlasColors.border,
        error: AtlasColors.danger,
      ),
      cardTheme: const CardThemeData(
        color: AtlasColors.surface,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AtlasColors.accent,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AtlasColors.textPrimary,
          side: const BorderSide(color: AtlasColors.border),
          shape: const RoundedRectangleBorder(borderRadius: borderRadius),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AtlasColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: AtlasColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: AtlasColors.border),
        ),
        hintStyle: TextStyle(color: AtlasColors.textMuted),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dividerTheme: const DividerThemeData(
        color: AtlasColors.border,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
