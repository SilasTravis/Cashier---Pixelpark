import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/update/update_script.dart';

// The one fixed input set the golden below is pinned to.
const _pid = 4242;
const _install = r'C:\Cashier\app';
const _staged = r'C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3';
const _backup = r'C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup';
const _exe = r'C:\Cashier\app\cashier_app.exe';
const _stagedExe =
    r'C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3\cashier_app.exe';

/// The exact text `buildUpdateScript` must produce for the inputs above.
/// Written out in full on purpose: this script runs unattended on a POS
/// machine, so every byte of it should be reviewable in one place.
const _goldenLines = <String>[
  r'@echo off',
  r'setlocal',
  r'rem Never run from inside a folder we are about to mirror over.',
  r'cd /d "%TEMP%"',
  r'set "LOG=%TEMP%\cashier_update.log"',
  r'',
  r'set /a tries=0',
  r':waitloop',
  r'tasklist /FI "PID eq 4242" /NH | find "4242" >nul',
  r'if errorlevel 1 goto gone',
  r'set /a tries+=1',
  r'if %tries% GEQ 60 (',
  r'  >>"%LOG%" echo [%DATE% %TIME%] Cashier PID 4242 is still running after 60s - update aborted, nothing changed.',
  r'  exit /b 1',
  r')',
  r'rem ping, not timeout: timeout needs a console handle, and this script is',
  r'rem launched detached with none, so timeout would fail instantly and the',
  r'rem loop would spin through all 60 tries in well under a second.',
  r'ping -n 2 127.0.0.1 >nul',
  r'goto waitloop',
  r'',
  r':gone',
  r'rem A staged folder that exists but is empty or half-extracted mirrors',
  r'rem without an error code and would wipe the install, so refuse to start',
  r'rem unless the new executable is actually there.',
  r'if not exist "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3\cashier_app.exe" (',
  r'  >>"%LOG%" echo [%DATE% %TIME%] Staged build has no cashier_app.exe - update aborted, nothing changed.',
  r'  start "" "C:\Cashier\app\cashier_app.exe"',
  r'  exit /b 1',
  r')',
  r'',
  r'if exist "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup" rmdir /s /q "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup"',
  r'robocopy "C:\Cashier\app" "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup" /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS >nul',
  r'set "rc=%ERRORLEVEL%"',
  r'if %rc% GEQ 8 (',
  r'  >>"%LOG%" echo [%DATE% %TIME%] Backup failed with robocopy code %rc% - update aborted, nothing changed.',
  r'  start "" "C:\Cashier\app\cashier_app.exe"',
  r'  exit /b 1',
  r')',
  r'',
  r'robocopy "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3" "C:\Cashier\app" /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS >nul',
  r'set "rc=%ERRORLEVEL%"',
  r'if %rc% GEQ 8 (',
  r'  >>"%LOG%" echo [%DATE% %TIME%] Update failed with robocopy code %rc% - restoring the previous version.',
  r'  goto restore',
  r')',
  r'rem Codes under 8 also cover a mirror that copied nothing, so confirm the',
  r'rem executable really landed before destroying the way back.',
  r'if not exist "C:\Cashier\app\cashier_app.exe" (',
  r'  >>"%LOG%" echo [%DATE% %TIME%] Update left no cashier_app.exe in the install folder - restoring the previous version.',
  r'  goto restore',
  r')',
  r'',
  r'start "" "C:\Cashier\app\cashier_app.exe"',
  r'rmdir /s /q "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup"',
  r'rmdir /s /q "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3"',
  r'(goto) 2>nul & del "%~f0"',
  r'exit /b 0',
  r'',
  r':restore',
  r'robocopy "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup" "C:\Cashier\app" /MIR /R:2 /W:1 /NFL /NDL /NJH /NJS >nul',
  r'set "rc=%ERRORLEVEL%"',
  r'if %rc% GEQ 8 (',
  r'  >>"%LOG%" echo [%DATE% %TIME%] Restore failed with robocopy code %rc% - the install is broken. Recover it by hand from "C:\Users\kassa\AppData\Roaming\cashier_app\updates\backup"',
  r'  exit /b 2',
  r')',
  r'start "" "C:\Cashier\app\cashier_app.exe"',
  r'exit /b 1',
  r'',
];

void main() {
  String script() => buildUpdateScript(
    pid: _pid,
    installDir: _install,
    stagedDir: _staged,
    backupDir: _backup,
    exePath: _exe,
  );

  test('generates exactly the reviewed script (golden)', () {
    expect(script(), _goldenLines.join('\r\n'));
  });

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
    expect(abort, isNot(contains('robocopy')));
    expect(abort, isNot(contains('rmdir')));
  });

  test('backs up, applies, and restores on failure', () {
    final text = script();
    final backup = text.indexOf('robocopy "$_install" "$_backup"');
    final apply = text.indexOf('robocopy "$_staged" "$_install"');
    final restore = text.indexOf('robocopy "$_backup" "$_install"');

    expect(backup, greaterThan(-1));
    expect(apply, greaterThan(backup));
    expect(restore, greaterThan(apply));
    expect(text, contains('/MIR'));
  });

  test('treats robocopy exit codes below 8 as success', () {
    // robocopy returns 1 for "files copied", 2 for "extras purged" and 3 for
    // both — every one of those is a success. `if errorlevel N` means
    // ">= N", so any `if errorlevel` on a robocopy result is a bug no
    // matter which number or label it is spelled with.
    final text = script();
    final firstRobocopy = text.indexOf('robocopy');
    expect(firstRobocopy, greaterThan(-1));
    final afterFirstRobocopy = text.substring(firstRobocopy);
    final offenders = RegExp(
      r'if\s+(not\s+)?errorlevel',
      caseSensitive: false,
    ).allMatches(afterFirstRobocopy);

    expect(
      offenders.map((m) => m.group(0)).toList(),
      isEmpty,
      reason: 'robocopy results must be tested with GEQ 8, not if errorlevel',
    );
    expect(text, contains('GEQ 8'));
  });

  test('relaunches the exe and cleans up after a successful apply', () {
    final text = script();
    expect(text, contains('start "" "$_exe"'));
    expect(text, contains('rmdir /s /q "$_staged"'));
    expect(text, contains(r'del "%~f0"'));
  });

  test('deletes the backup and staged copies only after relaunching', () {
    final text = script();
    // Everything from the apply onwards; the first relaunch after it is the
    // success-path one.
    final tail = text.substring(
      text.indexOf('robocopy "$_staged" "$_install"'),
    );
    final relaunch = tail.indexOf('start "" "$_exe"');
    final rmBackup = tail.indexOf('rmdir /s /q "$_backup"');
    final rmStaged = tail.indexOf('rmdir /s /q "$_staged"');

    expect(relaunch, greaterThan(-1));
    expect(
      rmBackup,
      greaterThan(relaunch),
      reason: 'the backup is the only way back; keep it until the app is up',
    );
    expect(rmStaged, greaterThan(relaunch));
    expect(tail.indexOf(r'del "%~f0"'), greaterThan(rmStaged));
  });

  test(
    'runs from TEMP so no working directory sits inside a copied folder',
    () {
      expect(script(), contains(r'cd /d "%TEMP%"'));
    },
  );

  test('quotes every path it uses', () {
    final text = buildUpdateScript(
      pid: 1,
      installDir: r'C:\Program Files\Cashier',
      stagedDir: r'C:\staged dir',
      backupDir: r'C:\backup dir',
      exePath: r'C:\Program Files\Cashier\cashier_app.exe',
    );
    const known = <String>{
      r'C:\Program Files\Cashier',
      r'C:\staged dir',
      r'C:\backup dir',
      r'C:\Program Files\Cashier\cashier_app.exe',
      r'C:\staged dir\cashier_app.exe',
    };

    // Every absolute path anywhere in the script — robocopy source *and*
    // destination, start, rmdir, if exist, log text — must open with a
    // quote and close with one before the end of its line.
    final paths = RegExp(r'[A-Za-z]:\\').allMatches(text).toList();
    expect(paths, isNotEmpty);
    for (final m in paths) {
      final before = text.substring(0, m.start);
      expect(
        before.isNotEmpty && before.endsWith('"'),
        isTrue,
        reason: 'unquoted path start at offset ${m.start}',
      );
      final close = text.indexOf('"', m.start);
      expect(close, greaterThan(-1), reason: 'unterminated quote');
      final quoted = text.substring(m.start, close);
      expect(quoted, isNot(contains('\n')), reason: 'quote never closes');
      expect(quoted, isNot(contains('\r')), reason: 'quote never closes');
      expect(
        known,
        contains(quoted),
        reason: 'unexpected or truncated path: $quoted',
      );
    }
  });

  // --- waiting -------------------------------------------------------------

  test('waits with ping, not timeout, because a detached script has no '
      'console', () {
    final text = script();
    // Only the `rem` lines explaining the choice may mention timeout.
    for (final line in text.split('\r\n')) {
      if (line.startsWith('rem ')) continue;
      expect(
        line,
        isNot(contains('timeout')),
        reason:
            'timeout.exe needs a console input handle and no-ops when '
            'detached, collapsing the wait loop',
      );
    }
    expect(text, contains('ping -n 2 127.0.0.1 >nul'));
    // 60 tries x ~1s per ping -n 2 is still roughly the advertised 60s.
    expect(text, contains('if %tries% GEQ 60'));
    expect(text, contains('60s'));
  });

  // --- incomplete staged build --------------------------------------------

  test('refuses to apply when the staged folder has no executable', () {
    final text = script();
    final guard = text.indexOf('if not exist "$_stagedExe" (');
    expect(
      guard,
      greaterThan(-1),
      reason:
          'robocopy /MIR from an empty-but-present staged folder returns '
          'a success code and empties the install folder',
    );
    // It must come before anything that writes to the install or backup.
    expect(guard, lessThan(text.indexOf('robocopy')));
    expect(guard, lessThan(text.indexOf('rmdir')));

    final block = text.substring(guard, text.indexOf('\r\n)\r\n', guard));
    expect(block, contains('start "" "$_exe"'));
    expect(block, contains('exit /b 1'));
    expect(block, contains(r'>>"%LOG%"'));
  });

  test('treats an apply that left no executable as a failure', () {
    final text = script();
    final apply = text.indexOf('robocopy "$_staged" "$_install"');
    final check = text.indexOf('if not exist "$_exe" (', apply);
    expect(
      check,
      greaterThan(apply),
      reason: 'robocopy codes below 8 do not prove the new build arrived',
    );
    // Before any cleanup, and it takes the restore path.
    expect(check, lessThan(text.indexOf('rmdir /s /q "$_backup"', apply)));
    final block = text.substring(check, text.indexOf('\r\n)\r\n', check));
    expect(block, contains('goto restore'));
    expect(block, isNot(contains('start ""')));
  });

  // --- failure branches ----------------------------------------------------

  test('a failed backup relaunches and never reaches the apply', () {
    final text = script();
    final backup = text.indexOf('robocopy "$_install" "$_backup"');
    final guard = text.indexOf('if %rc% GEQ 8 (', backup);
    final block = text.substring(guard, text.indexOf('\r\n)\r\n', guard));

    expect(block, contains('start "" "$_exe"'));
    expect(block, contains('exit /b 1'));
    for (final line in block.split('\r\n')) {
      expect(
        line.trimLeft(),
        isNot(startsWith('robocopy')),
        reason: 'without a backup there is nothing to fall back to',
      );
    }
    // The apply only appears after this branch has exited.
    expect(
      text.indexOf('robocopy "$_staged" "$_install"'),
      greaterThan(guard + block.length),
    );
  });

  test('a failed restore does not relaunch a half-restored install', () {
    final text = script();
    final tail = text.substring(text.indexOf(':restore'));
    expect(tail, contains('robocopy "$_backup" "$_install"'));

    final guard = tail.indexOf('if %rc% GEQ 8 (');
    expect(guard, greaterThan(-1), reason: 'the restore result is ignored');
    final block = tail.substring(guard, tail.indexOf('\r\n)\r\n', guard));

    expect(
      block,
      isNot(contains('start ""')),
      reason:
          'launching a mix of old and new files is worse than not '
          'launching at all',
    );
    expect(block, contains('exit /b 2'), reason: 'distinct non-zero code');
    expect(
      block,
      contains(_backup),
      reason: 'a technician needs to be told where the backup is',
    );
    // The relaunch lives after the failure block, not inside it.
    expect(tail.indexOf('start "" "$_exe"'), greaterThan(guard + block.length));
  });

  // --- diagnostics ---------------------------------------------------------

  test('writes every diagnostic to a log file under TEMP', () {
    final text = script();
    expect(text, contains(r'set "LOG=%TEMP%\cashier_update.log"'));

    // No diagnostic may go only to a console that closes on exit.
    for (final line in text.split('\r\n')) {
      if (line == '@echo off') continue;
      if (!line.contains('echo ')) continue;
      if (!line.trimLeft().startsWith(r'>>"%LOG%" echo ')) {
        fail('diagnostic not written to the log: $line');
      }
    }
    // Failing robocopy codes must be in the log text.
    for (final marker in [
      'Backup failed with robocopy code %rc%',
      'Update failed with robocopy code %rc%',
      'Restore failed with robocopy code %rc%',
    ]) {
      expect(text, contains(marker));
    }
  });

  test('no diagnostic contains a bare ) that would close an if block', () {
    for (final line in script().split('\r\n')) {
      if (line.contains('echo ')) {
        expect(
          line.substring(line.indexOf('echo ')),
          isNot(contains(')')),
          reason: 'an unescaped ) inside echo ends the enclosing block early',
        );
      }
    }
  });

  // --- line endings --------------------------------------------------------

  test('uses CRLF line endings throughout', () {
    final text = script();
    expect(text, contains('\r\n'));
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '\n') {
        expect(
          i > 0 && text[i - 1] == '\r',
          isTrue,
          reason:
              'bare LF at offset $i; cmd.exe seeks labels and parses '
              'multi-line if blocks by byte offset and mishandles LF-only '
              'batch files',
        );
      }
    }
  });
}
