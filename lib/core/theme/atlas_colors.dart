import 'package:flutter/material.dart';

/// Atlas design system color tokens.
///
/// These tokens map directly to the AtlasDesignSystem defined in Stitch.
abstract final class AtlasColors {
  /// Deepest background color.
  static const background = Color(0xFF0B0D10);

  /// Card and panel surface color.
  static const surface = Color(0xFF12151A);

  /// Elevated card surface color.
  static const surfaceElevated = Color(0xFF181C23);

  /// Default 1px border color.
  static const border = Color(0xFF242A33);

  /// Primary text color.
  static const textPrimary = Color(0xFFE8ECF2);

  /// Secondary / supporting text color.
  static const textSecondary = Color(0xFF8A94A6);

  /// Muted / disabled text color.
  static const textMuted = Color(0xFF566173);

  /// Indigo accent — primary actions and active states.
  static const accent = Color(0xFF4F46E5);

  /// Success / scores 7–10.
  static const success = Color(0xFF10B981);

  /// Warning / scores 4–6.
  static const warning = Color(0xFFF59E0B);

  /// Danger / scores 0–3.
  static const danger = Color(0xFFEF4444);
}
