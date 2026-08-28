import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:cashier_app/core/update/update_script.dart';
import 'package:cashier_app/core/update/windows_updater.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('updater_test'));
  tearDown(() => root.deleteSync(recursive: true));

  test('writes the script outside the install folder', () async {
    final updates = Directory('${root.path}/updates')..createSync();
    final staged = Directory('${updates.path}/v1.2.3')..createSync();
    final install = Directory('${root.path}/install')..createSync();

    final script = await const WindowsUpdater().writeScript(
      updatesDir: updates,
      staged: staged,
      installDir: install,
      exePath: '${install.path}/cashier_app.exe',
      pid: 99,
    );

    expect(script.existsSync(), isTrue);
    expect(script.path.startsWith(updates.path), isTrue);
    expect(script.path.startsWith(install.path), isFalse);
    expect(script.path, endsWith('.bat'));
  });

  test('the written script targets the given folders and pid', () async {
    final updates = Directory('${root.path}/updates')..createSync();
    final staged = Directory('${updates.path}/v1.2.3')..createSync();
    final install = Directory('${root.path}/install')..createSync();

    final script = await const WindowsUpdater().writeScript(
      updatesDir: updates,
      staged: staged,
      installDir: install,
      exePath: '${install.path}/cashier_app.exe',
      pid: 99,
    );
    final text = script.readAsStringSync();

    expect(text, contains('PID eq 99'));
    expect(text, contains('"${install.path}"'));
    expect(text, contains('"${staged.path}"'));
  });

  // Regression coverage for the three requirements carried over from Task
  // 3's review of the script itself — this is the task where they are
  // satisfied or silently lost.

  test('returns an absolute script path even when updatesDir is given as a '
      'relative path (Process.start needs an absolute one so the '
      'self-delete idiom %~f0 resolves against the right file)', () async {
    // This fixture must live on the SAME DRIVE as the current directory.
    // On Windows a relative path cannot span drives, so p.relative() falls
    // back to returning an absolute path — and GitHub's Windows runners put
    // Directory.systemTemp on C:\ while the checkout sits on D:\, which
    // made this test fail there while passing on macOS. Creating the root
    // under Directory.current keeps both on one drive everywhere.
    final sameDriveRoot = Directory.current.createTempSync('updater_reltest');
    addTearDown(() => sameDriveRoot.deleteSync(recursive: true));

    final updates = Directory('${sameDriveRoot.path}/updates')..createSync();
    final staged = Directory('${updates.path}/v1.2.3')..createSync();
    final install = Directory('${sameDriveRoot.path}/install')..createSync();

    // Every other fixture in this file builds updatesDir from
    // Directory.systemTemp, which is always absolute — so `.absolute`
    // being a no-op there can't prove the production code calls it. Drive
    // this one with a genuinely relative updatesDir instead, computed
    // against the process's current directory (never mutated) rather than
    // hand-written, so it resolves correctly regardless of where the test
    // runner's cwd happens to be.
    final relativeUpdates = Directory(
      p.relative(updates.path, from: Directory.current.path),
    );
    // Guards the fixture's own premise: if this ever fails, the paths are
    // on different drives again and the test below proves nothing.
    expect(p.isAbsolute(relativeUpdates.path), isFalse);

    final script = await const WindowsUpdater().writeScript(
      updatesDir: relativeUpdates,
      staged: staged,
      installDir: install,
      exePath: '${install.path}/cashier_app.exe',
      pid: 99,
    );

    expect(p.isAbsolute(script.path), isTrue);
    // Not just "some absolute path" — the same file the relative
    // updatesDir pointed at.
    expect(script.existsSync(), isTrue);
    expect(
      script.resolveSymbolicLinksSync(),
      equals(
        File(
          '${updates.path}${Platform.pathSeparator}apply_update.bat',
        ).resolveSymbolicLinksSync(),
      ),
    );
  });

  test('writes the script text exactly as buildUpdateScript produced it, '
      'preserving its CRLF line endings', () async {
    final updates = Directory('${root.path}/updates')..createSync();
    final staged = Directory('${updates.path}/v1.2.3')..createSync();
    final install = Directory('${root.path}/install')..createSync();
    const exePath = 'cashier_app.exe';

    final script = await const WindowsUpdater().writeScript(
      updatesDir: updates,
      staged: staged,
      installDir: install,
      exePath: exePath,
      pid: 99,
    );

    final expected = buildUpdateScript(
      pid: 99,
      installDir: install.path,
      stagedDir: staged.path,
      backupDir: backupDirPath(updates),
      exePath: exePath,
    );

    // Sanity check on the fixture itself: buildUpdateScript really does
    // emit CRLF, so the comparison below is meaningful.
    expect(expected, contains('\r\n'));
    expect(script.readAsStringSync(), equals(expected));
  });

  test(
    'never writes the script inside the install, staged, or backup folders',
    () async {
      final updates = Directory('${root.path}/updates')..createSync();
      final staged = Directory('${updates.path}/v1.2.3')..createSync();
      final install = Directory('${root.path}/install')..createSync();
      final backupDir = backupDirPath(updates);

      final script = await const WindowsUpdater().writeScript(
        updatesDir: updates,
        staged: staged,
        installDir: install,
        exePath: '${install.path}/cashier_app.exe',
        pid: 99,
      );

      expect(script.path.startsWith(install.path), isFalse);
      expect(script.path.startsWith(staged.path), isFalse);
      expect(script.path.startsWith(backupDir), isFalse);
      expect(script.path.startsWith(updates.path), isTrue);
    },
  );

  test(
    'a detached script leaves the wait when the cashier pid is gone',
    () async {
      if (!Platform.isWindows) return;

      final updates = Directory('${root.path}/updates')..createSync();
      final staged = Directory('${updates.path}/v1.2.3')..createSync();
      // `where.exe` is intentionally used as the fallback relaunch target:
      // with no arguments it exits immediately and cannot leave a test app
      // running. The empty staged folder then gives us a durable log marker
      // immediately after the wait without allowing robocopy to run.
      final harmlessExe =
          '${Platform.environment['SystemRoot']}'
          '${Platform.pathSeparator}System32${Platform.pathSeparator}where.exe';
      final install = File(harmlessExe).parent;
      const gonePid = 999999;

      final script = await const WindowsUpdater().writeScript(
        updatesDir: updates,
        staged: staged,
        installDir: install,
        exePath: harmlessExe,
        pid: gonePid,
      );

      await Process.start(
        'cmd.exe',
        ['/d', '/c', script.path],
        mode: ProcessStartMode.detached,
        // Never give the detached process a cwd inside the fixture: the
        // test may observe the final log line a few milliseconds before cmd
        // exits, and Windows will not delete a process's current directory.
        workingDirectory: Directory.systemTemp.path,
        environment: {'TEMP': root.path, 'TMP': root.path},
        includeParentEnvironment: true,
      );

      final log = File(
        '${root.path}${Platform.pathSeparator}cashier_update.log',
      );
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      String text = '';
      while (DateTime.now().isBefore(deadline)) {
        if (log.existsSync()) {
          text = log.readAsStringSync();
          if (text.contains('Staged build is incomplete')) break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      expect(text, contains('waiting for PID $gonePid'));
      expect(
        text,
        contains('Staged build is incomplete'),
        reason:
            'the detached wait must observe the dead PID and continue; the '
            'old tasklist | find pipeline stayed here forever',
      );
      expect(
        File(
          '${root.path}${Platform.pathSeparator}'
          'cashier_update_wait_$gonePid.txt',
        ).existsSync(),
        isFalse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));
    },
  );
}
