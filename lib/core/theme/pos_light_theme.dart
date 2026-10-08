import 'package:flutter/material.dart';

import 'app_text_styles.dart';
import 'nocturne_colors.dart';
import 'pos_palette.dart';

const _p = PosPalette.light;

TextStyle _ink(TextStyle base) => base.copyWith(color: _p.text);

/// Light, primary-blue theme for the "Akkaunt" workspace — scoped with a
/// `Theme` around `PosAccountPage`, so the rest of the till stays Nocturne.
/// Dialogs and menus opened from inside it capture this theme too.
final ThemeData posLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: _p.bg,
  canvasColor: _p.surface,
  fontFamily: AppTextStyles.body.fontFamily,
  colorScheme: ColorScheme.light(
    primary: _p.accent,
    onPrimary: _p.onAccent,
    secondary: _p.accent,
    surface: _p.surface,
    onSurface: _p.text,
    onSurfaceVariant: _p.textMuted,
    outline: _p.borderStrong,
    outlineVariant: _p.border,
    error: _p.danger,
    secondaryContainer: _p.accentSoft,
    onSecondaryContainer: _p.accent,
  ),
  textTheme: TextTheme(
    headlineLarge: _ink(AppTextStyles.h1),
    headlineMedium: _ink(AppTextStyles.h2),
    headlineSmall: _ink(AppTextStyles.h3),
    titleLarge: _ink(AppTextStyles.h4),
    titleMedium: _ink(AppTextStyles.h5),
    titleSmall: _ink(AppTextStyles.h6),
    bodyLarge: _ink(AppTextStyles.body),
    bodyMedium: _ink(AppTextStyles.body),
  ),
  cardTheme: CardThemeData(
    color: _p.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      side: BorderSide(color: _p.border),
    ),
  ),
  dividerTheme: DividerThemeData(color: _p.border, thickness: 1),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _p.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _p.borderStrong),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _p.borderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _p.accent, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _p.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _p.danger, width: 1.6),
    ),
    labelStyle: TextStyle(color: _p.textMuted),
    floatingLabelStyle: TextStyle(color: _p.accent),
    hintStyle: TextStyle(color: _p.textFaint),
    helperStyle: TextStyle(color: _p.textMuted, fontSize: 11),
    prefixIconColor: _p.textMuted,
    suffixIconColor: _p.textMuted,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: _p.accent,
      foregroundColor: _p.onAccent,
      disabledBackgroundColor: const Color(0xFFCBD5E1),
      disabledForegroundColor: _p.onAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w600),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _p.accentSoft,
      foregroundColor: _p.accent,
      elevation: 0,
      side: BorderSide(color: _p.accentBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: AppTextStyles.h5,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _p.text,
      backgroundColor: _p.surface,
      side: BorderSide(color: _p.borderStrong),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: _p.accent),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(foregroundColor: _p.textMuted),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.all(_p.surface),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? _p.accent
          : const Color(0xFFCBD5E1),
    ),
    trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: SegmentedButton.styleFrom(
      backgroundColor: _p.surface,
      foregroundColor: _p.textMuted,
      selectedBackgroundColor: _p.accentSoft,
      selectedForegroundColor: _p.accent,
      side: BorderSide(color: _p.borderStrong),
    ),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: _p.surface,
    surfaceTintColor: Colors.transparent,
    textStyle: _ink(AppTextStyles.body),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: _p.border),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: _p.surface,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: _ink(AppTextStyles.h4),
    contentTextStyle: _ink(AppTextStyles.body),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: _p.surface,
    surfaceTintColor: Colors.transparent,
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: _p.text,
      borderRadius: BorderRadius.circular(6),
    ),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(color: _p.accent),
  iconTheme: IconThemeData(color: _p.textMuted),
  scrollbarTheme: ScrollbarThemeData(
    thumbColor: WidgetStateProperty.all(_p.borderStrong),
    thickness: WidgetStateProperty.all(6),
  ),
  extensions: const [PosPalette.light],
);
