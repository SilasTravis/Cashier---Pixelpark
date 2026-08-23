import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/features/shell/presentation/model/shell_tab.dart';
import 'package:cashier_app/features/shell/presentation/widgets/sidebar.dart';

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
  testWidgets('shows no badge until an update is available', (tester) async {
    final flag = ValueNotifier<bool>(false);
    await _pump(tester, flag);

    expect(find.byKey(const Key('settings-update-badge')), findsNothing);

    flag.value = true;
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-update-badge')), findsOneWidget);
  });
}
