import 'package:cashier_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import 'helpers.dart';

final results = <String>[];

Future<void> settle(WidgetTester t, {int ms = 1500}) async {
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> step(WidgetTester t, String name, Future<void> Function() body) async {
  try {
    await body();
    results.add('OK   $name');
  } catch (e) {
    results.add('FAIL $name :: ${e.toString().split('\n').first}');
    try {
      await shot(t, 'FAIL_$name');
    } catch (_) {}
  }
}

Future<void> enterKey(WidgetTester t, String key, String v) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.enterText(f, v);
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> gotoEvents(WidgetTester t) async {
  await t.tap(find.byIcon(PhosphorIconsRegular.cake).first);
  await settle(t);
}

Future<void> openEvent(WidgetTester t, String who) async {
  await t.tap(find.textContaining(who).first);
  await settle(t);
}

Future<void> closeDetail(WidgetTester t) async {
  final x = find.byKey(const ValueKey('bd-detail-close'));
  if (x.evaluate().isNotEmpty) {
    await t.tap(x);
    await settle(t, ms: 600);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('events scenarios', (t) async {
    await boot(t, app.main);

    // E: a sale paid from the balance (mixed real+bonus customer)
    await step(t, 'E_sale_from_balance', () async {
      await openCustomer(t, '901234567', 'Aziza');
      await openSellDialog(t);
      await tapText(t, 'VIP');
      await tapKey(t, 'birthday-size-5');
      await tapText(t, '+7 kun');
      final sw = find.descendant(of: find.byKey(const ValueKey('bd-balance-row')), matching: find.byType(Switch));
      await t.ensureVisible(sw);
      await t.tap(sw);
      await t.pump(const Duration(milliseconds: 500));
      await shot(t, 'E1_full_from_balance_plus_cash');
      await tapText(t, 'Karta');
      await shot(t, 'E2_balance_plus_card');
      await tapKey(t, 'birthday-submit');
      await settle(t, ms: 3000);
      await shot(t, 'E3_after_sale_balance_used');
      await t.tap(find.byIcon(PhosphorIconsRegular.arrowsClockwise).first);
      await settle(t);
      await shot(t, 'E4_customer_balance_refreshed');
    });

    await gotoEvents(t);
    await shot(t, 'F0_events_list');

    await step(t, 'F1_add_payment', () async {
      await openEvent(t, 'Aziza');
      await shot(t, 'F1_detail');
      await tapKey(t, 'bd-add-payment');
      await settle(t, ms: 800);
      await shot(t, 'F2_pay_sheet');
      await enterKey(t, 'bd-pay-amount', '99 000 000');
      await shot(t, 'F3_pay_over_debt');
      await enterKey(t, 'bd-pay-amount', '500 000');
      await tapKey(t, 'bd-pay-submit');
      await settle(t, ms: 2500);
      await shot(t, 'F4_after_payment');
    });

    await step(t, 'F5_comment', () async {
      await enterKey(t, 'bd-comment-field', 'Mijoz tort rangini so‘radi — pushti');
      await tapKey(t, 'bd-comment-send');
      await settle(t, ms: 1500);
      await shot(t, 'F5_comment_added');
    });

    await step(t, 'F6_add_child', () async {
      await tapKey(t, 'bd-more');
      await settle(t, ms: 500);
      await shot(t, 'F6_more_menu');
      await t.tap(find.text('+ bola').last);
      await settle(t, ms: 800);
      await tapKey(t, 'bd-child-plus');
      await tapKey(t, 'bd-child-plus');
      await shot(t, 'F7_add_children_dialog');
      await tapKey(t, 'bd-child-submit');
      await settle(t, ms: 2500);
      await shot(t, 'F8_after_add_children');
    });

    await step(t, 'F9_change_date', () async {
      await tapKey(t, 'bd-more');
      await settle(t, ms: 500);
      await t.tap(find.text('Sanani o‘zgartirish').last);
      await settle(t, ms: 800);
      await shot(t, 'F9_change_date_picker');
      await t.tap(find.text('OK').first);
      await settle(t, ms: 2500);
      await shot(t, 'F10_after_change_date');
    });

    await step(t, 'F11_cancel_dialog_validations', () async {
      await tapKey(t, 'bd-more');
      await settle(t, ms: 500);
      await t.tap(find.text('Bekor qilish').last);
      await settle(t, ms: 800);
      await shot(t, 'F11_cancel_dialog_empty');
      await enterKey(t, 'bd-cancel-reason', 'ab');
      await shot(t, 'F12_cancel_reason_short');
      await enterKey(t, 'bd-cancel-reason', 'Mijoz fikridan qaytdi');
      await tapKey(t, 'bd-cancel-refund');
      await settle(t, ms: 500);
      await shot(t, 'F13_cancel_refund_form');
      await t.tap(find.text('Naqd').last);
      await settle(t, ms: 300);
      await shot(t, 'F14_cancel_refund_cash_form');
    });

    await step(t, 'F15_cancel_confirm', () async {
      // refund everything to balance
      await t.tap(find.text('Balansga').last);
      await settle(t, ms: 400);
      await shot(t, 'F15_cancel_to_balance');
      await tapKey(t, 'bd-cancel-confirm');
      await settle(t, ms: 3000);
      await shot(t, 'F16_after_cancel');
    });

    await step(t, 'G_complete_with_debt', () async {
      await closeDetail(t);
      await gotoEvents(t);
      await openEvent(t, 'Balanssiz');
      await shot(t, 'G1_detail_today');
      await tapKey(t, 'bd-complete');
      await settle(t, ms: 800);
      await shot(t, 'G2_complete_debt_confirm');
      await tapKey(t, 'bd-complete-confirm');
      await settle(t, ms: 3000);
      await shot(t, 'G3_after_complete');
    });

    await step(t, 'H_tabs', () async {
      await closeDetail(t);
      await t.tap(find.text('Yakunlangan').first);
      await settle(t);
      await shot(t, 'H1_completed_tab');
      await t.tap(find.text('Bekor qilingan').first);
      await settle(t);
      await shot(t, 'H2_cancelled_tab');
    });

    // ignore: avoid_print
    print('\n==== RESULTS ====\n${results.join('\n')}\n=================');
    expect(results.where((r) => r.startsWith('FAIL')), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
