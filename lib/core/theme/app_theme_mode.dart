import 'package:flutter/foundation.dart';

/// The till's light / night choice — one app-wide switch, remembered per
/// device (`LocalSource.getDarkMode`). [NocturneColors] and the themes read
/// it; `App` rebuilds every widget when it flips.
abstract final class AppThemeMode {
  static final ValueNotifier<bool> notifier = ValueNotifier(false);

  static bool get dark => notifier.value;
}
