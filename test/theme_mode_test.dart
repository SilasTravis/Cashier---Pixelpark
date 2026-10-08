import 'dart:io';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/core/theme/app_theme.dart';
import 'package:cashier_app/core/theme/app_theme_mode.dart';
import 'package:cashier_app/core/theme/nocturne_colors.dart';
import 'package:cashier_app/core/theme/pos_palette.dart';
import 'package:cashier_app/core/theme/theme_mode_toggle.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory temp;
  late Box<dynamic> box;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cashier_theme');
    Hive.init(temp.path);
    box = await Hive.openBox<dynamic>('cashier_app_box');
    sl.registerSingleton<LocalSource>(LocalSource(box));
  });

  tearDown(() async {
    AppThemeMode.notifier.value = false;
    await sl.reset();
    await box.close();
    await temp.delete(recursive: true);
  });

  test('tokens and the palette follow the mode', () {
    expect(NocturneColors.bg, PosPalette.light.bg);
    AppThemeMode.notifier.value = true;
    expect(NocturneColors.bg, PosPalette.dark.bg);
    expect(NocturneColors.surface, PosPalette.dark.surface);
    expect(PosPalette.current, PosPalette.dark);
    expect(appDarkTheme.brightness, Brightness.dark);
    expect(appDarkTheme.extension<PosPalette>(), PosPalette.dark);
  });

  test('night mode is off until switched on, then remembered', () async {
    final local = sl<LocalSource>();
    expect(local.getDarkMode(), isFalse);
    await local.setDarkMode(true);
    await local.clearSession();
    expect(local.getDarkMode(), isTrue);
  });

  testWidgets('the button flips the mode and keeps widget state', (
    tester,
  ) async {
    // Saving is covered above; a Hive write never settles under the fake
    // clock, so the button runs without a store here (it checks for one).
    await sl.unregister<LocalSource>();
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: AppThemeMode.notifier,
        builder: (context, dark, _) => MaterialApp(
          theme: dark ? appDarkTheme : appTheme,
          localizationsDelegates: const [AppLocalization.delegate],
          supportedLocales: AppLocalization.delegate.supportedLocales,
          home: const Scaffold(
            body: Column(children: [ThemeModeButton(), _Counter()]),
          ),
        ),
      ),
    );
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-mode-button')));
    await tester.pumpAndSettle();

    expect(AppThemeMode.dark, isTrue);
    // A widget reading the static tokens was repainted with night colors…
    final box = tester.widget<ColoredBox>(find.byKey(const ValueKey('bg')));
    expect(box.color, PosPalette.dark.bg);
    // …and kept its state.
    expect(find.text('1'), findsOneWidget);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('bg'),
    color: NocturneColors.bg,
    child: Row(
      children: [
        Text('$n'),
        TextButton(
          onPressed: () => setState(() => n++),
          child: const Text('+'),
        ),
      ],
    ),
  );
}
