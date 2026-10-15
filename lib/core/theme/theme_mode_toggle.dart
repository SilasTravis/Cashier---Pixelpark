import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../../generated/l10n.dart';
import '../../injector_container.dart';
import '../local_source/local_source.dart';
import 'app_theme_mode.dart';
import 'nocturne_colors.dart';
import 'pos_palette.dart';

/// Switches the till between light and night mode, remembers it, and
/// repaints every widget: [NocturneColors] are read at build time, so only a
/// full rebuild picks the new values up — screens, open dialogs and their
/// state stay as they were (the same walk a hot reload does).
void setThemeMode({required bool dark}) {
  if (AppThemeMode.dark == dark) return;
  AppThemeMode.notifier.value = dark;
  if (sl.isRegistered<LocalSource>()) sl<LocalSource>().setDarkMode(dark);
  windowManager.setBackgroundColor(NocturneColors.bg).catchError((_) {});
  WidgetsBinding.instance.addPostFrameCallback((_) {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  });
}

/// Moon / sun button for the top bar — one tap flips the mode.
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final dark = AppThemeMode.dark;
    return Tooltip(
      message: dark ? l10n.themeDay : l10n.themeNight,
      child: InkWell(
        key: const ValueKey('theme-mode-button'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => setThemeMode(dark: !dark),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderStrong),
          ),
          child: Icon(
            dark ? PhosphorIconsRegular.sun : PhosphorIconsRegular.moon,
            size: 18,
            color: p.textMuted,
          ),
        ),
      ),
    );
  }
}
