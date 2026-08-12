import 'package:flutter/widgets.dart';

/// Global navigator key so non-widget code (the token refresher ending an
/// expired session) can redirect to the login screen.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

abstract final class Routes {
  static const String login = '/login';
  static const String shell = '/shell';
}
