import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/features/shell/presentation/model/shell_tab.dart';
import 'package:cashier_app/features/shell/presentation/widgets/sidebar.dart';

Key _badgeKey(ShellTab tab) => Key('nav-update-badge-${tab.name}');

Future<void> _pump(WidgetTester tester, ValueNotifier<bool> flag) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalization.delegate],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Row(
          children: [
            Sidebar(
              selected: ShellTab.posAccount,
              collapsed: false,
              onToggle: () {},
              onSelect: (_) {},
              cashierName: 'Zaira',
              shiftOpenedAt: DateTime(2026, 8, 23, 9),
              onCloseShift: () {},
              updateAvailable: flag,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the badge appears only on the Settings tile, and clears from it '
      'when the flag flips back to false', (tester) async {
    final flag = ValueNotifier<bool>(false);
    await _pump(tester, flag);

    // Nothing badged yet, on any tab.
    for (final tab in ShellTab.values) {
      expect(find.byKey(_badgeKey(tab)), findsNothing);
    }

    flag.value = true;
    await tester.pumpAndSettle();

    // Badged on Settings, and only Settings — this is the assertion the
    // previous version of this test couldn't make: it checked only that
    // *a* badge existed somewhere, which would still pass if the badge
    // condition were keyed off the selected tab instead of
    // ShellTab.settings.
    for (final tab in ShellTab.values) {
      final finder = find.byKey(_badgeKey(tab));
      if (tab == ShellTab.settings) {
        expect(finder, findsOneWidget);
      } else {
        expect(finder, findsNothing);
      }
    }

    // The true -> false clearing transition: previously untested.
    flag.value = false;
    await tester.pumpAndSettle();

    for (final tab in ShellTab.values) {
      expect(find.byKey(_badgeKey(tab)), findsNothing);
    }
  });
}
