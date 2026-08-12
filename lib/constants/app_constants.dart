/// Backend base URL. Overridable per build via
/// `flutter run --dart-define=API_BASE_URL=https://test.api.pixelpark.uz/api`;
/// defaults to the shared test API so a plain `flutter run` works out of
/// the box during development.
abstract final class AppConstants {
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://test.api.pixelpark.uz/api',
  );

  /// Minimum window size — below `800x?` the design's dense panel layout
  /// (200px sidebar + 286px keypad + content) no longer fits.
  static const double minWindowWidth = 800;
  static const double minWindowHeight = 600;
}
