import 'package:cashier_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'helpers.dart';

final results = <String>[];

Future<void> step(WidgetTester t, String name, Future<void> Function() body) async {
  try {
    await body();
    results.add('OK   $name');
  } catch (e) {
    results.add('FAIL $name :: ${e.toString().split('\n').first}');
    try {
      await shot(t, 'FAIL_$name');
    } catch (_) {}
    await closeSellDialog(t);
  }
}

Future<void> setTotal(WidgetTester t, String v) async {
  final f = find.descendant(
    of: find.byKey(const ValueKey('birthday-total-field')),
    matching: find.byType(EditableText),
  );
  await t.enterText(f, v);
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> waitDialogGone(WidgetTester t) async {
  for (var i = 0; i < 40; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 100));
    if (find.byKey(const ValueKey('birthday-close-x')).evaluate().isEmpty) break;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('birthday sale scenarios', (t) async {
    await boot(t, app.main);

    await openCustomer(t, '901234567', 'Aziza');

    await step(t, 'A1_default_and_tiers', () async {
      await openSellDialog(t);
      await shot(t, 'A1_default');
      await tapText(t, 'Standart');
      await tapText(t, 'O‘rta');
      await tapText(t, 'VIP');
      await tapKey(t, 'birthday-size-10');
      await shot(t, 'A4_vip_10');
    });

    await step(t, 'A5_extra_children_and_dates', () async {
      await tapKey(t, 'birthday-extra-plus');
      await tapKey(t, 'birthday-extra-plus');
      await tapText(t, '+7 kun');
      await tapText(t, 'Ertaga');
      await tapText(t, 'Boshqa sana');
      await t.pump(const Duration(milliseconds: 800));
      await shot(t, 'A6_date_picker');
      await t.tap(find.text('OK').first);
      await t.pump(const Duration(milliseconds: 600));
    });

    await step(t, 'A7_deposit_and_payment_methods', () async {
      await tapText(t, 'Zaklad');
      await tapKey(t, 'birthday-deposit-chip-200000');
      await tapText(t, 'Karta');
      await tapText(t, 'Aralash');
      await shot(t, 'A9_deposit_aralash');
      await tapText(t, 'Naqd');
    });

    await step(t, 'A10_balance_toggle', () async {
      final sw = find.descendant(of: find.byKey(const ValueKey('bd-balance-row')), matching: find.byType(Switch));
      await t.ensureVisible(sw);
      await t.tap(sw);
      await t.pump(const Duration(milliseconds: 500));
      await shot(t, 'A10_deposit_from_balance');
    });

    await step(t, 'A11_manual_price_discount', () async {
      await setTotal(t, '2 600 000');
      await shot(t, 'A11_manual_price_discount');
      await setTotal(t, '');
      await shot(t, 'A12_total_cleared');
      await setTotal(t, '2 740 000');
    });

    await step(t, 'A13_validation_deposit', () async {
      final f = find.byKey(const ValueKey('birthday-deposit-field'));
      await t.ensureVisible(f);
      await t.enterText(f, '99 000 000');
      await t.pump(const Duration(milliseconds: 500));
      await shot(t, 'A13_deposit_over_total');
      await t.enterText(f, '0');
      await t.pump(const Duration(milliseconds: 500));
      await t.enterText(f, '');
      await t.pump(const Duration(milliseconds: 500));
      await tapKey(t, 'birthday-deposit-chip-200000');
    });

    await step(t, 'A16_full_payment_with_balance', () async {
      await tapText(t, 'To‘liq to‘lov');
      await shot(t, 'A16_full_with_balance');
    });

    await step(t, 'A17_submit_deposit_success', () async {
      await tapText(t, 'Zaklad');
      await tapKey(t, 'birthday-deposit-chip-200000');
      await tapKey(t, 'birthday-submit');
      await waitDialogGone(t);
      await shot(t, 'A18_after_submit');
    });

    await step(t, 'B_bonus_only_customer', () async {
      await openCustomer(t, '901111111', 'Bonus');
      await openSellDialog(t);
      await tapText(t, 'Standart');
      await tapKey(t, 'birthday-size-5');
      await tapText(t, 'Zaklad');
      await tapKey(t, 'birthday-deposit-chip-200000');
      await shot(t, 'B1_bonus_only');
      await closeSellDialog(t);
    });

    await step(t, 'C_zero_balance_customer', () async {
      await openCustomer(t, '902222222', 'Balanssiz');
      await openSellDialog(t);
      await tapText(t, 'Standart');
      await tapKey(t, 'birthday-size-5');
      await tapText(t, 'Zaklad');
      await tapKey(t, 'birthday-deposit-chip-100000');
      await tapText(t, 'Karta');
      await tapKey(t, 'birthday-submit');
      await waitDialogGone(t);
      await shot(t, 'C3_after_submit');
    });

    await step(t, 'D_events_tab', () async {
      await t.tap(find.byIcon(PhosphorIconsRegular.cake).first);
      await t.pump(const Duration(seconds: 2));
      await waitFor(t, find.textContaining('Aziza'), secs: 10);
      await shot(t, 'D1_events_list');
    });

    // ignore: avoid_print
    print('\n==== RESULTS ====\n${results.join('\n')}\n=================');
    expect(results.where((r) => r.startsWith('FAIL')), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
