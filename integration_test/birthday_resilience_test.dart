import 'dart:io';

import 'package:cashier_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

/// Backend checkout the test may kill and restart (`--dart-define=BACKEND_DIR=...`).
const backendDir = String.fromEnvironment('BACKEND_DIR');
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

Future<bool> backendUp() async {
  try {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final r = await (await c.getUrl(Uri.parse('http://localhost:4000/api/v1/pos/birthday-plans'))).close();
    return r.statusCode > 0;
  } catch (_) {
    return false;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('resilience', (t) async {
    await boot(t, app.main);
    await openCustomer(t, '901234567', 'Aziza');

    await step(t, 'R3_backend_down_then_retry', () async {
      await openSellDialog(t);
      await tapText(t, 'O‘rta');
      await tapKey(t, 'birthday-size-5');
      await tapText(t, 'Zaklad');
      await tapKey(t, 'birthday-deposit-chip-100000');
      await t.runAsync(() async {
        await Process.run('sh', ['-c', 'kill \$(lsof -ti tcp:4000 -sTCP:LISTEN)']);
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tapKey(t, 'birthday-submit');
      for (var i = 0; i < 120; i++) {
        await settle(t, ms: 250);
        if (find.byKey(const ValueKey('birthday-unclear-hint')).evaluate().isNotEmpty ||
            find.byKey(const ValueKey('birthday-offline-hint')).evaluate().isNotEmpty ||
            find.byKey(const ValueKey('birthday-error')).evaluate().isNotEmpty) {
          break;
        }
      }
      await shot(t, 'R3_backend_down_hint');
      // bring the backend back
      await t.runAsync(() async {
        await Process.start('sh', ['-c', 'cd $backendDir && nohup npx nest start > /tmp/pp-backend2.log 2>&1 &']);
        for (var i = 0; i < 90 && !await backendUp(); i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      });
      await shot(t, 'R4_backend_back_before_retry');
      final no = find.byWidgetPredicate((w) => w is Text && RegExp(r'^Yo.q$').hasMatch(w.data ?? ''));
      if (no.evaluate().isNotEmpty) {
        await t.tap(no.first);
        await settle(t, ms: 800);
      }
      await shot(t, 'R4b_modal_dismissed');
      await tapKey(t, 'birthday-submit');
      await settle(t, ms: 3500);
      await shot(t, 'R5_after_retry');
    });

    // ignore: avoid_print
    print('\n==== RESULTS ====\n${results.join('\n')}\n=================');
    expect(results.where((r) => r.startsWith('FAIL')), isEmpty);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
