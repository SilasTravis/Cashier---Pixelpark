import 'package:flutter/material.dart';

import 'app_theme_mode.dart';

/// The till's color tokens. Originally the dark "Nocturne" palette; since
/// the light / primary-blue redesign every token keeps its ROLE (page,
/// card, text, tint, tint text, border …) with a light value, so screens
/// that still read these constants directly render in the new design.
///
/// Each token resolves for the current [AppThemeMode] (light, or the soft
/// blue-slate night mode), so they are getters, never `const`.
///
/// Prefer `PosPalette.of(context)` in new code.
abstract final class NocturneColors {
  /// Page canvas behind the cards.
  static Color get bg =>
      AppThemeMode.dark ? const Color(0xFF1B2536) : const Color(0xFFF4F6FA);

  /// Cards, panels, dialogs.
  static Color get surface =>
      AppThemeMode.dark ? const Color(0xFF243044) : const Color(0xFFFFFFFF);

  /// Body text.
  static Color get text =>
      AppThemeMode.dark ? const Color(0xFFE8EEF7) : const Color(0xFF0F172A);

  /// Hairlines and field borders.
  static Color get divider =>
      AppThemeMode.dark ? const Color(0xFF34445C) : const Color(0xFFE4E8F0);

  /// Primary blue — selected states, links, primary actions.
  static Color get accent =>
      AppThemeMode.dark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  static Color get accent2 =>
      AppThemeMode.dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

  // Accent scale by ROLE (it reads "inverted" against a light canvas):
  // 900 = tint fill, 700 = tint border, 300 = text/icon on a tint.
  static Color get accent100 =>
      AppThemeMode.dark ? const Color(0xFFDCE8FF) : const Color(0xFF172554);
  static Color get accent200 =>
      AppThemeMode.dark ? const Color(0xFFC2D7FF) : const Color(0xFF1E3A8A);
  static Color get accent300 =>
      AppThemeMode.dark ? const Color(0xFF9CC2FF) : const Color(0xFF1E40AF);
  static Color get accent400 =>
      AppThemeMode.dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
  static Color get accent500 =>
      AppThemeMode.dark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);
  static Color get accent600 =>
      AppThemeMode.dark ? const Color(0xFF2563EB) : const Color(0xFF1D4ED8);
  static Color get accent700 =>
      AppThemeMode.dark ? const Color(0xFF3D5B8C) : const Color(0xFFBFD3FE);
  static Color get accent800 =>
      AppThemeMode.dark ? const Color(0xFF324A73) : const Color(0xFFDBE6FE);
  static Color get accent900 =>
      AppThemeMode.dark ? const Color(0xFF2A3F63) : const Color(0xFFEFF4FF);

  // Neutral scale by ROLE: 100 = text on a solid accent, 200/300 = strong
  // text on a tint, 400–600 = muted icons/text, 700/800 = borders,
  // 900 = inset fill.
  static Color get neutral100 =>
      AppThemeMode.dark ? const Color(0xFFFFFFFF) : const Color(0xFFFFFFFF);
  static Color get neutral200 =>
      AppThemeMode.dark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
  static Color get neutral300 =>
      AppThemeMode.dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  static Color get neutral400 =>
      AppThemeMode.dark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);
  static Color get neutral500 =>
      AppThemeMode.dark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8);
  static Color get neutral600 =>
      AppThemeMode.dark ? const Color(0xFFA7B4C8) : const Color(0xFF64748B);
  static Color get neutral700 =>
      AppThemeMode.dark ? const Color(0xFF43556F) : const Color(0xFFD5DBE6);
  static Color get neutral800 =>
      AppThemeMode.dark ? const Color(0xFF34445C) : const Color(0xFFE4E8F0);
  static Color get neutral900 =>
      AppThemeMode.dark ? const Color(0xFF2C3A51) : const Color(0xFFF1F5F9);

  /// Semantic aliases used across the app — a single place to retune status
  /// colors without hunting through every screen.
  static Color get danger =>
      AppThemeMode.dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get success =>
      AppThemeMode.dark ? const Color(0xFF34D399) : const Color(0xFF16A34A);

  /// Offline-mode amber — the banner and "waiting" chips.
  static Color get warning =>
      AppThemeMode.dark ? const Color(0xFFF5B547) : const Color(0xFFD97706);
}

/// Border radii — `--radius-sm/md/lg`.
abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
}

/// Spacing scale — `--space-1..8`.
abstract final class AppSpacing {
  static const double x1 = 2.8;
  static const double x2 = 5.6;
  static const double x3 = 8.4;
  static const double x4 = 11.2;
  static const double x6 = 16.8;
  static const double x8 = 22.4;
}

/// Box shadows: a 1px hairline (the cards' border) plus, at md/lg, a soft
/// drop shadow for floating surfaces.
abstract final class AppShadow {
  static List<BoxShadow> get sm => [
    BoxShadow(color: NocturneColors.divider, spreadRadius: 1, blurRadius: 0),
  ];
  static List<BoxShadow> get md => [
    BoxShadow(color: NocturneColors.divider, spreadRadius: 1, blurRadius: 0),
    BoxShadow(
      color: AppThemeMode.dark
          ? const Color(0x33000000)
          : const Color(0x140F172A),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
  static List<BoxShadow> get lg => [
    BoxShadow(color: NocturneColors.neutral700, spreadRadius: 1, blurRadius: 0),
    BoxShadow(
      color: AppThemeMode.dark
          ? const Color(0x4D000000)
          : const Color(0x1F0F172A),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];
}
