import 'package:flutter/material.dart';

import 'app_text_styles.dart';
import 'app_theme_mode.dart';

/// Screen-level color tokens of the light / primary-blue design, resolved
/// from the ambient [Theme] (see `posLightTheme`). Read with [PosPalette.of].
@immutable
class PosPalette extends ThemeExtension<PosPalette> {
  const PosPalette({
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentSoft,
    required this.accentBorder,
    required this.accentStrong,
    required this.onAccent,
    required this.positive,
    required this.positiveSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
  });

  /// Page canvas behind the cards.
  final Color bg;

  /// Card / panel surface.
  final Color surface;

  /// Inset fills inside a card — keypad keys, rows, tab tracks.
  final Color surfaceMuted;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color border;
  final Color borderStrong;
  final Color accent;

  /// Selected-state fill behind accent content.
  final Color accentSoft;
  final Color accentBorder;

  /// Accent used for big numbers (balance) — darker than [accent] on light.
  final Color accentStrong;
  final Color onAccent;

  /// "OK" signals — balance covers, split matches, child inside.
  final Color positive;
  final Color positiveSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  static const light = PosPalette(
    bg: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F5F9),
    text: Color(0xFF0F172A),
    textMuted: Color(0xFF64748B),
    textFaint: Color(0xFF94A3B8),
    border: Color(0xFFE4E8F0),
    borderStrong: Color(0xFFD5DBE6),
    accent: Color(0xFF2563EB),
    accentSoft: Color(0xFFEFF4FF),
    accentBorder: Color(0xFFDBE6FE),
    accentStrong: Color(0xFF1E40AF),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF16A34A),
    positiveSoft: Color(0xFFECFDF3),
    warning: Color(0xFFB45309),
    warningSoft: Color(0xFFFFF7E6),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0xFFFEF2F2),
  );

  /// Night mode: a soft blue-slate, not black — easy on the eyes in a dim
  /// hall without the harsh contrast of a pure dark theme.
  static const dark = PosPalette(
    bg: Color(0xFF1B2536),
    surface: Color(0xFF243044),
    surfaceMuted: Color(0xFF2C3A51),
    text: Color(0xFFE8EEF7),
    textMuted: Color(0xFFA7B4C8),
    textFaint: Color(0xFF7F8DA3),
    border: Color(0xFF34445C),
    borderStrong: Color(0xFF43556F),
    accent: Color(0xFF3B82F6),
    accentSoft: Color(0xFF2A3F63),
    accentBorder: Color(0xFF3D5B8C),
    accentStrong: Color(0xFF9CC2FF),
    onAccent: Color(0xFFFFFFFF),
    positive: Color(0xFF34D399),
    positiveSoft: Color(0xFF1F3D3A),
    warning: Color(0xFFF5B547),
    warningSoft: Color(0xFF40361F),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF472A31),
  );

  /// The palette for the current [AppThemeMode].
  static PosPalette get current => AppThemeMode.dark ? dark : light;

  /// Falls back to [current] — widget tests pumping a bare MaterialApp get
  /// the same colors as the app.
  static PosPalette of(BuildContext context) =>
      Theme.of(context).extension<PosPalette>() ?? current;

  @override
  PosPalette copyWith() => this;

  @override
  PosPalette lerp(ThemeExtension<PosPalette>? other, double t) =>
      t < 0.5 || other is! PosPalette ? this : other;
}

/// [AppTextStyles] inked with the palette's text colors — the base styles
/// hard-code Nocturne's light-on-dark text.
extension PosPaletteText on PosPalette {
  TextStyle get body => AppTextStyles.body.copyWith(color: text);
  TextStyle get bodyMuted => AppTextStyles.body.copyWith(color: textMuted);
  TextStyle get title =>
      AppTextStyles.h4.copyWith(color: text, fontWeight: FontWeight.w700);
  TextStyle get heading =>
      AppTextStyles.h5.copyWith(color: text, fontWeight: FontWeight.w600);
  TextStyle get kicker => AppTextStyles.kicker.copyWith(color: textFaint);
}
