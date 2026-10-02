import 'package:flutter/material.dart';

import 'app_text_styles.dart';
import 'nocturne_colors.dart';

/// The single dark theme this app ever renders — Nocturne has no light
/// variant, unlike pexel_app's Light/Dark pair.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: NocturneColors.bg,
  canvasColor: NocturneColors.bg,
  fontFamily: AppTextStyles.body.fontFamily,
  colorScheme: const ColorScheme.dark(
    surface: NocturneColors.surface,
    primary: NocturneColors.accent,
    secondary: NocturneColors.accent400,
    error: NocturneColors.danger,
    onSurface: NocturneColors.text,
    onPrimary: NocturneColors.neutral100,
  ),
  textTheme: const TextTheme(
    headlineLarge: AppTextStyles.h1,
    headlineMedium: AppTextStyles.h2,
    headlineSmall: AppTextStyles.h3,
    titleLarge: AppTextStyles.h4,
    titleMedium: AppTextStyles.h5,
    titleSmall: AppTextStyles.h6,
    bodyMedium: AppTextStyles.body,
  ),
  cardTheme: CardThemeData(
    color: NocturneColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: const BorderSide(color: NocturneColors.neutral800),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: NocturneColors.divider,
    thickness: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: NocturneColors.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: NocturneColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: NocturneColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: NocturneColors.accent),
    ),
    hintStyle: TextStyle(color: NocturneColors.text.withValues(alpha: 0.4)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: NocturneColors.accent.withValues(alpha: 0.12),
      foregroundColor: NocturneColors.accent,
      side: const BorderSide(color: NocturneColors.accent),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: AppTextStyles.h5,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: NocturneColors.text.withValues(alpha: 0.85),
      side: const BorderSide(color: NocturneColors.divider),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  ),
  iconTheme: const IconThemeData(color: NocturneColors.neutral500),
  scrollbarTheme: ScrollbarThemeData(
    thumbColor: WidgetStateProperty.all(NocturneColors.neutral800),
    thickness: WidgetStateProperty.all(6),
  ),
);
