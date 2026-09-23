import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/locale_cubit.dart';
import 'core/offline/app_mode_cubit.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/shell/presentation/pages/shell_page.dart';
import 'injector_container.dart';
import 'core/local_source/local_source.dart';
import 'router/app_navigator.dart';
import 'generated/l10n.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final hasSession = sl<LocalSource>().getAccessToken() != null;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<LocaleCubit>()),
        // `.value`: the singleton outlives this widget; never closed here.
        BlocProvider<AppModeCubit>.value(value: sl<AppModeCubit>()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) => MaterialApp(
          onGenerateTitle: (context) => AppLocalization.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          navigatorKey: rootNavigatorKey,
          theme: appTheme,
          darkTheme: appTheme,
          themeMode: ThemeMode.dark,
          locale: locale,
          supportedLocales: AppLocalization.delegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalization.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: hasSession ? Routes.shell : Routes.login,
          routes: {
            Routes.login: (_) => const LoginPage(),
            Routes.shell: (_) => const ShellPage(),
          },
        ),
      ),
    );
  }
}
