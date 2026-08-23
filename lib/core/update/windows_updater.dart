import 'dart:io';

import 'update_script.dart';

/// Hands the folder swap off to a detached batch script and quits, because
/// a running executable can't replace its own files.
class WindowsUpdater {
  const WindowsUpdater();

  /// The folder the running executable lives in — the folder to replace.
  Directory installDirectory() => File(Platform.resolvedExecutable).parent;

  /// Writes the script into [updatesDir]. Never into the install folder:
  /// that folder is about to be mirrored over, which would delete the
  /// script mid-run.
  ///
  /// Returned as `.absolute` deliberately: the script ends with the
  /// self-delete idiom `(goto) 2>nul & del "%~f0"`, and `%~f0` resolves
  /// against the *current* directory, which the script itself sets to
  /// `%TEMP%`. Launching with anything less than an absolute path would
  /// make the self-delete target the wrong file — resolving it here means
  /// every caller (including `apply`) gets it for free.
  Future<File> writeScript({
    required Directory updatesDir,
    required Directory staged,
    required Directory installDir,
    required String exePath,
    required int pid,
  }) async {
    final script = File(
      '${updatesDir.path}${Platform.pathSeparator}apply_update.bat',
    ).absolute;
    await script.writeAsString(
      buildUpdateScript(
        pid: pid,
        installDir: installDir.path,
        stagedDir: staged.path,
        backupDir: '${updatesDir.path}${Platform.pathSeparator}backup',
        exePath: exePath,
      ),
    );
    return script;
  }

  /// Starts the script detached and exits so the script can take over. Does
  /// not return.
  Future<Never> apply({
    required Directory updatesDir,
    required Directory staged,
  }) async {
    final installDir = installDirectory();
    final script = await writeScript(
      updatesDir: updatesDir,
      staged: staged,
      installDir: installDir,
      exePath: Platform.resolvedExecutable,
      pid: pid,
    );

    await Process.start(
      'cmd.exe',
      ['/c', script.path],
      mode: ProcessStartMode.detached,
      workingDirectory: Directory.systemTemp.path,
    );
    exit(0);
  }
}
