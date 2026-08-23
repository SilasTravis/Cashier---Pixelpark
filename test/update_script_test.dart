import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/update_script.dart';

void main() {
  String script() => buildUpdateScript(
    pid: 4242,
    installDir: r'C:\Cashier\app',
    stagedDir: r'C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3',
    backupDir: r'C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup',
    exePath: r'C:\Cashier\app\cashier_app.exe',
  );

  test('waits for the old process to exit before touching anything', () {
    final text = script();
    final waitIndex = text.indexOf('tasklist /FI "PID eq 4242"');
    final copyIndex = text.indexOf('robocopy');

    expect(waitIndex, greaterThan(-1));
    expect(copyIndex, greaterThan(waitIndex));
  });

  test('aborts without copying if the process outlives the timeout', () {
    final text = script();
    expect(text, contains('if %tries% GEQ 60'));
    // The abort branch must not relaunch: the old app is still running.
    final abort = text.substring(
      text.indexOf('if %tries% GEQ 60'),
      text.indexOf(':gone'),
    );
    expect(abort, contains('exit /b 1'));
    expect(abort, isNot(contains('start ""')));
  });

  test('backs up, applies, and restores on failure', () {
    final text = script();
    final backup = text.indexOf(
      r'robocopy "C:\Cashier\app" "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup"',
    );
    final apply = text.indexOf(
      r'robocopy "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3" "C:\Cashier\app"',
    );
    final restore = text.indexOf(
      r'robocopy "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup" "C:\Cashier\app"',
    );

    expect(backup, greaterThan(-1));
    expect(apply, greaterThan(backup));
    expect(restore, greaterThan(apply));
    expect(text, contains('/MIR'));
  });

  test('treats robocopy exit codes below 8 as success', () {
    // robocopy returns 1 for "files copied" — a plain `if errorlevel 1`
    // check would read every successful update as a failure.
    expect(script(), contains('GEQ 8'));
    expect(script(), isNot(contains('if errorlevel 1 goto restore')));
  });

  test('relaunches the exe and cleans up after a successful apply', () {
    final text = script();
    expect(text, contains(r'start "" "C:\Cashier\app\cashier_app.exe"'));
    expect(text, contains(r'rmdir /s /q "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3"'));
    expect(text, contains(r'del "%~f0"'));
  });

  test('runs from TEMP so no working directory sits inside a copied folder', () {
    expect(script(), contains(r'cd /d "%TEMP%"'));
  });

  test('quotes every path so spaces in the install folder are safe', () {
    final text = buildUpdateScript(
      pid: 1,
      installDir: r'C:\Program Files\Cashier',
      stagedDir: r'C:\staged dir',
      backupDir: r'C:\backup dir',
      exePath: r'C:\Program Files\Cashier\cashier_app.exe',
    );

    expect(text, contains(r'"C:\Program Files\Cashier"'));
    expect(text, contains(r'"C:\staged dir"'));
    expect(text, isNot(contains(r'robocopy C:\Program Files')));
  });
}
