import 'package:cashier_app/features/shell/presentation/model/shell_tab.dart';
import 'package:cashier_app/features/shell/presentation/widgets/top_nav.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'offline, internet-only tabs ignore taps; the unsynced tab shows its count',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final tapped = <ShellTab>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalization.delegate],
          supportedLocales: AppLocalization.delegate.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Column(
              children: [
                TopNav(
                  selected: ShellTab.posSale,
                  onSelect: tapped.add,
                  cashierName: 'Zaira',
                  shiftOpenedAt: DateTime(2026, 9, 23, 9),
                  onCloseShift: null,
                  updateAvailable: ValueNotifier(false),
                  tabs: const [...ShellTab.primary, ShellTab.unsynced],
                  disabledTabs: {
                    for (final t in ShellTab.values)
                      if (t.needsInternet) t,
                  },
                  counts: const {ShellTab.unsynced: 3},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(ShellTab.posAccount.icon));
      await tester.tap(find.byIcon(ShellTab.posSale.icon));
      await tester.tap(find.byIcon(ShellTab.unsynced.icon));

      expect(tapped, [ShellTab.posSale, ShellTab.unsynced]);
      expect(find.byKey(const Key('nav-count-unsynced')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets('a disabled close-shift button explains why', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalization.delegate],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Column(
            children: [
              TopNav(
                selected: ShellTab.posSale,
                onSelect: (_) {},
                cashierName: 'Zaira',
                shiftOpenedAt: DateTime(2026, 9, 23, 9),
                onCloseShift: null,
                closeShiftDisabledReason: 'offline',
                updateAvailable: ValueNotifier(false),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('offline'), findsOneWidget);
  });
}
