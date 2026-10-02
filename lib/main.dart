// Entry point of the Bolajon cashier terminal (Windows POS).
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'constants/app_constants.dart';
import 'core/connectivity/connectivity_monitor.dart';
import 'core/terminal/terminal_heartbeat_service.dart';
import 'core/theme/nocturne_colors.dart';
import 'core/update/update_service.dart';
import 'injector_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  di.sl<UpdateService>().startBackgroundChecks();
  di.sl<ConnectivityMonitor>().start();
  di.sl<TerminalHeartbeatService>().start();

  await windowManager.ensureInitialized();
  // Dev-only launch-size override for testing small cashier screens:
  // `flutter run --dart-define=WINDOW_SIZE=1280x760`. Defaults to the
  // design size when unset.
  const sizeOverride = String.fromEnvironment('WINDOW_SIZE');
  final launchSize = switch (sizeOverride.split('x')) {
    [final w, final h] when double.tryParse(w) != null && double.tryParse(h) != null =>
      Size(double.parse(w), double.parse(h)),
    _ => const Size(1440, 900),
  };
  final windowOptions = WindowOptions(
    size: launchSize,
    minimumSize: Size(
      AppConstants.minWindowWidth,
      AppConstants.minWindowHeight,
    ),
    center: true,
    backgroundColor: NocturneColors.bg,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const App());
}
