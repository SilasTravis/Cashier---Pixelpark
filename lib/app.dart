import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/shell/presentation/pages/shell_page.dart';
import 'injector_container.dart';
import 'core/local_source/local_source.dart';
import 'router/app_navigator.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final hasSession = sl<LocalSource>().getAccessToken() != null;

    return MaterialApp(
      title: 'Bolajon — kassa',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: appTheme,
      darkTheme: appTheme,
      themeMode: ThemeMode.dark,
      initialRoute: hasSession ? Routes.shell : Routes.login,
      routes: {
        Routes.login: (_) => const LoginPage(),
        Routes.shell: (_) => const ShellPage(),
      },
    );
  }
}
