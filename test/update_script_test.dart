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
// The other two things a Flutter Windows build cannot start without.
const _stagedDll =
    r'C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3\flutter_windows.dll';
// Directories are tested with a trailing backslash — the canonical
// `if exist "path\"` directory test in cmd.
const _stagedData =
    r'C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3\data'
    '\\';
const _installDll = r'C:\Cashier\app\flutter_windows.dll';
const _installData = r'C:\Cashier\app\data' '\\';

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
  r'rem unless the whole new build is there. The executable alone is not',
  r'rem enough: package:archive drops a file it cannot write without raising',
  r'rem anything, and a Flutter build with no flutter_windows.dll or no data',
  r'rem folder installs cleanly and then fails to launch.',
  r'set "staged_ok=1"',
  r'if not exist "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3\cashier_app.exe" set "staged_ok="',
  r'if not exist "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3\flutter_windows.dll" set "staged_ok="',
  r'if not exist "C:\Users\kassa\AppData\Roaming\cashier_app\updates\v1.2.3\data\" set "staged_ok="',
  r'if not defined staged_ok (',
  r'  >>"%LOG%" echo [%DATE% %TIME%] Staged build is incomplete - update aborted, nothing changed.',
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
  r'rem new build really landed before relaunching.',
  r'set "install_ok=1"',
  r'if not exist "C:\Cashier\app\cashier_app.exe" set "install_ok="',
  r'if not exist "C:\Cashier\app\flutter_windows.dll" set "install_ok="',
  r'if not exist "C:\Cashier\app\data\" set "install_ok="',
  r'if not defined install_ok (',
  r'  >>"%LOG%" echo [%DATE% %TIME%] Update left an incomplete install - restoring the previous version.',
  r'  goto restore',
  r')',
  r'',
  r'start "" "C:\Cashier\app\cashier_app.exe"',
  r'rem The backup deliberately survives. start only proves the process was',
  r'rem created, not that it stayed up, and nobody is watching this till: a',
  r'rem build that dies on a missing DLL must still have something to roll',
  r'rem back to. The next update reclaims this folder before taking its own',
  r'rem backup, so it costs one stale copy on disk and buys a one-folder',
  r'rem copy back to a working install.',
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

  test('keeps the backup after a successful apply', () {
    final text = script();
    // The success path only: from the relaunch to the restore label.
    final tail = text.substring(
      text.indexOf('robocopy "$_staged" "$_install"'),
    );
    final relaunch = tail.indexOf('start "" "$_exe"');
    expect(relaunch, greaterThan(-1));
    final success = tail.substring(relaunch, tail.indexOf(':restore'));

    expect(
      success,
      isNot(contains('rmdir /s /q "$_backup"')),
      reason:
          'start only proves the process was created, not that it survived. '
          'A build that dies on a missing DLL leaves an unattended till with '
          'nothing to roll back to once the backup is gone.',
    );
    // The staged copy is genuinely spent, so that one still goes.
    final rmStaged = success.indexOf('rmdir /s /q "$_staged"');
    expect(rmStaged, greaterThan(-1));
    expect(success.indexOf(r'del "%~f0"'), greaterThan(rmStaged));
  });

  test('removes the backup only when reclaiming it for the next update', () {
    final text = script();
    final reclaim = text.indexOf('if exist "$_backup" rmdir /s /q "$_backup"');
    expect(reclaim, greaterThan(-1));
    expect(
      reclaim,
      lessThan(text.indexOf('robocopy "$_install" "$_backup"')),
      reason: 'a stale backup must go before this run writes its own',
    );
    // Keeping the backup costs one folder, not an unbounded pile: the
    // reclaim above is the only place it is ever deleted.
    final deletions = RegExp(
      'rmdir /s /q "${RegExp.escape(_backup)}"',
    ).allMatches(text);
    expect(deletions.length, 1);
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
      r'C:\staged dir\flutter_windows.dll',
      r'C:\staged dir\data' '\\',
      r'C:\Program Files\Cashier\flutter_windows.dll',
      r'C:\Program Files\Cashier\data' '\\',
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

  test('refuses to apply unless the whole staged build is present', () {
    final text = script();
    final guard = text.indexOf('set "staged_ok=1"');
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
    // The exe alone is not proof: package:archive silently skips a file it
    // cannot write, so a tree holding only the exe reaches this point.
    expect(block, contains('if not exist "$_stagedExe" set "staged_ok="'));
    expect(block, contains('if not exist "$_stagedDll" set "staged_ok="'));
    expect(block, contains('if not exist "$_stagedData" set "staged_ok="'));
    expect(block, contains('if not defined staged_ok ('));
    expect(block, contains('start "" "$_exe"'));
    expect(block, contains('exit /b 1'));
    expect(block, contains(r'>>"%LOG%"'));
  });

  test('treats an apply that left an incomplete install as a failure', () {
    final text = script();
    final apply = text.indexOf('robocopy "$_staged" "$_install"');
    final check = text.indexOf('set "install_ok=1"', apply);
    expect(
      check,
      greaterThan(apply),
      reason: 'robocopy codes below 8 do not prove the new build arrived',
    );
    // Before the relaunch and any cleanup, and it takes the restore path.
    expect(check, lessThan(text.indexOf('start "" "$_exe"', apply)));
    expect(check, lessThan(text.indexOf('rmdir /s /q "$_staged"', apply)));
    final block = text.substring(check, text.indexOf('\r\n)\r\n', check));
    expect(block, contains('if not exist "$_exe" set "install_ok="'));
    expect(block, contains('if not exist "$_installDll" set "install_ok="'));
    expect(block, contains('if not exist "$_installData" set "install_ok="'));
    expect(block, contains('if not defined install_ok ('));
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
