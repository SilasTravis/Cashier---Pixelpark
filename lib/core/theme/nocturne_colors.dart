import 'package:flutter/material.dart';

/// The till's color tokens. Originally the dark "Nocturne" palette; since
/// the light / primary-blue redesign every token keeps its ROLE (page,
/// card, text, tint, tint text, border …) with a light value, so screens
/// that still read these constants directly render in the new design.
///
/// Prefer `PosPalette.of(context)` in new code.
abstract final class NocturneColors {
  /// Page canvas behind the cards.
  static const Color bg = Color(0xFFF4F6FA);

  /// Cards, panels, dialogs.
  static const Color surface = Color(0xFFFFFFFF);

  /// Body text.
  static const Color text = Color(0xFF0F172A);

  /// Hairlines and field borders.
  static const Color divider = Color(0xFFE4E8F0);

  /// Primary blue — selected states, links, primary actions.
  static const Color accent = Color(0xFF2563EB);
  static const Color accent2 = Color(0xFF3B82F6);

  // Accent scale by ROLE (it reads "inverted" against a light canvas):
  // 900 = tint fill, 700 = tint border, 300 = text/icon on a tint.
  static const Color accent100 = Color(0xFF172554);
  static const Color accent200 = Color(0xFF1E3A8A);
  static const Color accent300 = Color(0xFF1E40AF);
  static const Color accent400 = Color(0xFF3B82F6);
  static const Color accent500 = Color(0xFF2563EB);
  static const Color accent600 = Color(0xFF1D4ED8);
  static const Color accent700 = Color(0xFFBFD3FE);
  static const Color accent800 = Color(0xFFDBE6FE);
  static const Color accent900 = Color(0xFFEFF4FF);

  // Neutral scale by ROLE: 100 = text on a solid accent, 200/300 = strong
  // text on a tint, 400–600 = muted icons/text, 700/800 = borders,
  // 900 = inset fill.
  static const Color neutral100 = Color(0xFFFFFFFF);
  static const Color neutral200 = Color(0xFF1E293B);
  static const Color neutral300 = Color(0xFF334155);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral500 = Color(0xFF94A3B8);
  static const Color neutral600 = Color(0xFF64748B);
  static const Color neutral700 = Color(0xFFD5DBE6);
  static const Color neutral800 = Color(0xFFE4E8F0);
  static const Color neutral900 = Color(0xFFF1F5F9);

  /// Semantic aliases used across the app — a single place to retune status
  /// colors without hunting through every screen.
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);

  /// Offline-mode amber — the banner and "waiting" chips.
  static const Color warning = Color(0xFFD97706);
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
  static const List<BoxShadow> sm = [
    BoxShadow(color: NocturneColors.divider, spreadRadius: 1, blurRadius: 0),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: NocturneColors.divider, spreadRadius: 1, blurRadius: 0),
    BoxShadow(color: Color(0x140F172A), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(color: NocturneColors.neutral700, spreadRadius: 1, blurRadius: 0),
    BoxShadow(color: Color(0x1F0F172A), blurRadius: 40, offset: Offset(0, 16)),
  ];
}
