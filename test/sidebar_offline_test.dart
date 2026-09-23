import 'package:cashier_app/features/shell/presentation/model/shell_tab.dart';
import 'package:cashier_app/features/shell/presentation/widgets/sidebar.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'offline, internet-only tabs ignore taps; the unsynced tab shows its count',
    (tester) async {
      final tapped = <ShellTab>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppLocalization.delegate],
          supportedLocales: AppLocalization.delegate.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Row(
              children: [
                Sidebar(
                  selected: ShellTab.posSale,
                  collapsed: false,
                  onToggle: () {},
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
      final l10n = AppLocalization.current;

      await tester.tap(find.text(l10n.tabAccount));
      await tester.tap(find.text(l10n.tabSales));
      await tester.tap(find.text(l10n.tabUnsynced));

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
          body: Row(
            children: [
              Sidebar(
                selected: ShellTab.posSale,
                collapsed: false,
                onToggle: () {},
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
