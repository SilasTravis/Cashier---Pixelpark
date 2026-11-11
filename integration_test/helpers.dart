import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cashier_app/features/pos_account/presentation/widgets/phone_keypad.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where screenshots go (`--dart-define=SHOT_DIR=...`).
final shotDir = Directory(
  const String.fromEnvironment('SHOT_DIR', defaultValue: '/tmp/pp_cashier_shots'),
)..createSync(recursive: true);

Future<void> shot(WidgetTester t, String name) async {
  await t.pump(const Duration(milliseconds: 400));
  final view = t.binding.renderViews.first;
  final layer = view.debugLayer as OffsetLayer;
  final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File('${shotDir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Pump until [f] finds something or [secs] pass (real network in between).
Future<bool> waitFor(WidgetTester t, Finder f, {int secs = 15}) async {
  for (var i = 0; i < secs * 5; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 100));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

Future<void> typePhone(WidgetTester t, String nineDigits) async {
  for (final d in nineDigits.split('')) {
    await t.tap(find.descendant(of: find.byType(PhoneKeypad), matching: find.text(d)).first);
    await t.pump(const Duration(milliseconds: 80));
  }
}

/// Start the real app and make sure we end up on the till home (logged in).
Future<void> boot(WidgetTester t, FutureOr<void> Function() mainFn) async {
  mainFn();
  await t.pump(const Duration(seconds: 2));
  final home = find.text('Telefon raqami');
  await waitFor(t, find.byType(TextField), secs: 20);
  if (home.evaluate().isEmpty) {
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), const String.fromEnvironment('CASHIER_USER', defaultValue: 'kassir1'));
    await t.enterText(fields.at(1), const String.fromEnvironment('CASHIER_PASS', defaultValue: 'Kassa12345!'));
    await t.testTextInput.receiveAction(TextInputAction.done);
  }
  await waitFor(t, home, secs: 20);
}

Future<void> tapKey(WidgetTester t, String key, {int settleMs = 400}) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pump(Duration(milliseconds: settleMs));
}

Future<void> tapText(WidgetTester t, String text, {int settleMs = 400}) async {
  final f = find.text(text).first;
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 150));
  await t.tap(f);
  await t.pump(Duration(milliseconds: settleMs));
}

/// Search a customer by the keypad and open the detail panel.
Future<void> openCustomer(WidgetTester t, String nineDigits, String name) async {
  // back to the search if a customer is open
  if (find.byKey(const ValueKey('customer-detail')).evaluate().isNotEmpty) {
    await t.tap(find.byIcon(PhosphorIconsRegular.arrowLeft).first);
    await t.pump(const Duration(milliseconds: 600));
  }
  // clear any digits
  for (var i = 0; i < 12; i++) {
    final del = find.descendant(of: find.byType(PhoneKeypad), matching: find.byIcon(PhosphorIconsRegular.backspace));
    if (del.evaluate().isEmpty) break;
    await t.tap(del.first);
    await t.pump(const Duration(milliseconds: 30));
  }
  await typePhone(t, nineDigits);
  await waitFor(t, find.textContaining(name), secs: 10);
  await t.tap(find.textContaining(name).first);
  await waitFor(t, find.byKey(const ValueKey('customer-detail')), secs: 10);
  await t.pump(const Duration(seconds: 1));
}

Future<void> openSellDialog(WidgetTester t) async {
  final card = find.byKey(const ValueKey('service-birthday-card'));
  await t.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).hitTestable().first);
  await t.tap(card);
  await waitFor(t, find.byKey(const ValueKey('birthday-close-x')), secs: 15);
  await t.pump(const Duration(seconds: 1));
}

Future<void> closeSellDialog(WidgetTester t) async {
  final x = find.byKey(const ValueKey('birthday-close-x'));
  if (x.evaluate().isNotEmpty) {
    await t.tap(x);
    await t.pump(const Duration(milliseconds: 600));
  }
}
