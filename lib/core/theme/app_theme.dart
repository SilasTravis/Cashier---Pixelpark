import 'package:flutter/material.dart';

import 'pos_light_theme.dart';

/// The till's one theme: light, primary blue (see `posLightTheme`). The old
/// dark "Nocturne" theme is retired — `NocturneColors` now carries the light
/// values under the same token names.
final ThemeData appTheme = posLightTheme;

/// The night counterpart of [appTheme] — see `AppThemeMode`.
final ThemeData appDarkTheme = posDarkTheme;
