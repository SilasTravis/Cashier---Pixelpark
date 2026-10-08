import 'package:flutter/material.dart';

import 'app_text_styles.dart';
import 'nocturne_colors.dart';
import 'pos_palette.dart';

/// The till's light, primary-blue theme.
final ThemeData posLightTheme = posTheme(PosPalette.light);

/// The soft blue-slate night theme — same shapes, [PosPalette.dark] colors.
final ThemeData posDarkTheme = posTheme(PosPalette.dark);

/// One theme built from a palette, so light and night never drift apart.
/// Dialogs and menus capture it too.
ThemeData posTheme(PosPalette p) {
  final isDark = identical(p, PosPalette.dark);
  TextStyle ink(TextStyle base) => base.copyWith(color: p.text);
  final disabledFill = isDark ? p.borderStrong : const Color(0xFFCBD5E1);
  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.surface,
    fontFamily: AppTextStyles.body.fontFamily,
    colorScheme: (isDark ? ColorScheme.dark : ColorScheme.light)(
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textMuted,
      outline: p.borderStrong,
      outlineVariant: p.border,
      error: p.danger,
      secondaryContainer: p.accentSoft,
      onSecondaryContainer: p.accent,
    ),
    textTheme: TextTheme(
      headlineLarge: ink(AppTextStyles.h1),
      headlineMedium: ink(AppTextStyles.h2),
      headlineSmall: ink(AppTextStyles.h3),
      titleLarge: ink(AppTextStyles.h4),
      titleMedium: ink(AppTextStyles.h5),
      titleSmall: ink(AppTextStyles.h6),
      bodyLarge: ink(AppTextStyles.body),
      bodyMedium: ink(AppTextStyles.body),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: p.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: p.danger, width: 1.6),
      ),
      labelStyle: TextStyle(color: p.textMuted),
      floatingLabelStyle: TextStyle(color: p.accent),
      hintStyle: TextStyle(color: p.textFaint),
      helperStyle: TextStyle(color: p.textMuted, fontSize: 11),
      prefixIconColor: p.textMuted,
      suffixIconColor: p.textMuted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: disabledFill,
        disabledForegroundColor: p.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.accentSoft,
        foregroundColor: p.accent,
        elevation: 0,
        side: BorderSide(color: p.accentBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: AppTextStyles.h5,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        backgroundColor: p.surface,
        side: BorderSide(color: p.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accent),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: p.textMuted),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(p.surface),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? p.accent : disabledFill,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: p.surface,
        foregroundColor: p.textMuted,
        selectedBackgroundColor: p.accentSoft,
        selectedForegroundColor: p.accent,
        side: BorderSide(color: p.borderStrong),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: ink(AppTextStyles.body),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: ink(AppTextStyles.h4),
      contentTextStyle: ink(AppTextStyles.body),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.text,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    iconTheme: IconThemeData(color: p.textMuted),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(p.borderStrong),
      thickness: WidgetStateProperty.all(6),
    ),
    extensions: [p],
  );
}
