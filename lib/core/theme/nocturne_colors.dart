import 'package:flutter/material.dart';

/// Color tokens lifted 1:1 from the Cashier design system's "Nocturne"
/// `styles.css` (dark-only — this POS terminal has no light theme).
abstract final class NocturneColors {
  static const Color bg = Color(0xFF161826);
  static const Color surface = Color(0xFF232532);
  static const Color text = Color(0xFFE9E9ED);
  static const Color divider = Color(0x29E9E9ED); // 16% alpha

  static const Color accent = Color(0xFF9184D9);
  static const Color accent2 = Color(0xFFA7A1DB);

  static const Color accent100 = Color(0xFFF5F4FF);
  static const Color accent200 = Color(0xFFE7E5FE);
  static const Color accent300 = Color(0xFFD2CEFD);
  static const Color accent400 = Color(0xFFB5ABFC);
  static const Color accent500 = Color(0xFF968AE0);
  static const Color accent600 = Color(0xFF796CBF);
  static const Color accent700 = Color(0xFF5D5294);
  static const Color accent800 = Color(0xFF423A6A);
  static const Color accent900 = Color(0xFF2B2741);

  static const Color neutral100 = Color(0xFFF3F5FE);
  static const Color neutral200 = Color(0xFFE4E7F5);
  static const Color neutral300 = Color(0xFFCFD3E5);
  static const Color neutral400 = Color(0xFFB2B6CA);
  static const Color neutral500 = Color(0xFF9397AB);
  static const Color neutral600 = Color(0xFF75798C);
  static const Color neutral700 = Color(0xFF595D6C);
  static const Color neutral800 = Color(0xFF3F424D);
  static const Color neutral900 = Color(0xFF292B31);

  /// Semantic aliases used across the app — a single place to retune status
  /// colors without hunting through every screen.
  static const Color danger = Color(0xFF8C2F3C);
  static const Color success = accent400;
}

/// Border radii — `--radius-sm/md/lg`.
abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 8;
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

/// Box shadows — `--shadow-sm/md/lg`, expressed as a hairline border (this
/// design's "shadow" is really a 1px outline plus, at md/lg, an ambient
/// drop shadow) since Nocturne is a dark theme.
abstract final class AppShadow {
  static const List<BoxShadow> sm = [
    BoxShadow(color: NocturneColors.neutral800, spreadRadius: 1, blurRadius: 0),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: NocturneColors.neutral700, spreadRadius: 1, blurRadius: 0),
    BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(color: NocturneColors.neutral500, spreadRadius: 1, blurRadius: 0),
    BoxShadow(color: Color(0xA6000000), blurRadius: 40, offset: Offset(0, 16)),
  ];
}
