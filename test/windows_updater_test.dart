import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

  test('returns an absolute script path (Process.start needs one so the '
      'self-delete idiom %~f0 resolves against the right file)', () async {
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

    // A path is absolute exactly when resolving it against `.absolute`
    // is a no-op. If a future edit stopped absolutizing the path, this
    // would fail even though updatesDir here happens to already be
    // absolute (it's a temp dir).
    expect(script.path, equals(script.absolute.path));
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
      backupDir: '${updates.path}${Platform.pathSeparator}backup',
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
      final backupDir = '${updates.path}${Platform.pathSeparator}backup';

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
}
