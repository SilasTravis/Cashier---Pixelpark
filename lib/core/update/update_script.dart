/// Builds the batch script that replaces the install folder after the app
/// exits. Kept as a pure function so its exact text is testable — this is
/// the one part of the updater that runs outside Dart, where a mistake
/// means a broken install on a POS machine.
///
/// `robocopy /MIR` rather than a folder rename: rename fails when the
/// staging folder (under %APPDATA%) and the install folder live on
/// different drives. Note that /MIR mirrors — anything in the install
/// folder that isn't part of the new build is removed.
///
/// Two things about robocopy drive the shape of the script. Its exit code
/// is a bitmask where everything below 8 is a success (1 = files copied,
/// 2 = extras purged, 3 = both), so results are tested with `GEQ 8` and
/// never with `if errorlevel`. And a source folder that exists but is
/// empty or half-extracted mirrors *successfully* while emptying the
/// destination, so the build is checked for by name on both sides of the
/// apply.
///
/// Those name checks cover the executable, `flutter_windows.dll` and the
/// `data\` folder rather than the executable alone. `package:archive`
/// silently skips any file it fails to write, so a half-extracted staged
/// folder can hold a perfectly good `cashier_app.exe` and nothing else —
/// an exe-only check would mirror that over a working install and leave a
/// till that cannot start.
///
/// The backup is deliberately *not* deleted on the success path. `start`
/// returns as soon as the process is created and never observes whether it
/// survived, so deleting the backup there would throw away the only way
/// back from a build that dies on a missing DLL — on a machine with no
/// operator in front of it. The stale backup is reclaimed at the top of
/// the next update instead, which bounds the cost at one app-sized folder.
///
/// The script is launched detached, which is why it waits with `ping`
/// instead of `timeout` (timeout needs a console *input* handle) and why
/// every diagnostic is appended to %TEMP%\cashier_update.log. A console
/// window does appear on real tills, so the script titles it and tells
/// the cashier not to close it — the first field test proved a cashier
/// will close a mystery window, which kills the wait pipeline and
/// force-skips the wait.
///
/// The wait filters tasklist by IMAGENAME as well as PID. Windows recycles
/// a freed PID immediately, and the loop's own per-iteration children
/// (find, ping, conhost) kept landing on the app's just-freed PID — so a
/// PID-only check saw "still running" forever, a self-sustaining wedge
/// observed on the first real till.
String buildUpdateScript({
  required int pid,
  required String installDir,
  required String stagedDir,
  required String backupDir,
  required String exePath,
}) {
  const flags = '/MIR /R:2 /W:1 /NFL /NDL /NJH /NJS';
  // Derived here rather than taken as a parameter: the caller's signature
  // is fixed, and the exe's name is already implied by exePath.
  final exeName = exePath.split(RegExp(r'[\\/]')).last;
  final stagedExe = '$stagedDir\\$exeName';
  // The rest of the minimum viable Flutter Windows build. Directories are
  // tested with a trailing backslash, which is what makes `if exist` in cmd
  // match a folder rather than a file of the same name.
  final stagedDll = '$stagedDir\\flutter_windows.dll';
  final stagedData = '$stagedDir\\data\\';
  final installedDll = '$installDir\\flutter_windows.dll';
  final installedData = '$installDir\\data\\';

  final script =
      '''
@echo off
setlocal
rem Never run from inside a folder we are about to mirror over.
cd /d "%TEMP%"
set "LOG=%TEMP%\\cashier_update.log"
title Cashier yangilanishi / Cashier update
echo Ilova yangilanmoqda. Bu oynani YOPMANG - u ozi yopiladi.
echo The app is updating. Do NOT close this window - it closes itself.
>>"%LOG%" echo [%DATE% %TIME%] Update script started - waiting for PID $pid - $exeName - to exit.

set /a tries=0
:waitloop
tasklist /FI "PID eq $pid" /FI "IMAGENAME eq $exeName" /NH | find "$pid" >nul
if errorlevel 1 goto gone
set /a tries+=1
if %tries% GEQ 60 (
  >>"%LOG%" echo [%DATE% %TIME%] Cashier PID $pid is still running after 60s - update aborted, nothing changed.
  exit /b 1
)
rem ping, not timeout: timeout needs a console handle, and this script is
rem launched detached with none, so timeout would fail instantly and the
rem loop would spin through all 60 tries in well under a second.
ping -n 2 127.0.0.1 >nul
goto waitloop

:gone
rem A staged folder that exists but is empty or half-extracted mirrors
rem without an error code and would wipe the install, so refuse to start
rem unless the whole new build is there. The executable alone is not
rem enough: package:archive drops a file it cannot write without raising
rem anything, and a Flutter build with no flutter_windows.dll or no data
rem folder installs cleanly and then fails to launch.
set "staged_ok=1"
if not exist "$stagedExe" set "staged_ok="
if not exist "$stagedDll" set "staged_ok="
if not exist "$stagedData" set "staged_ok="
if not defined staged_ok (
  >>"%LOG%" echo [%DATE% %TIME%] Staged build is incomplete - update aborted, nothing changed.
  start "" "$exePath"
  exit /b 1
)

if exist "$backupDir" rmdir /s /q "$backupDir"
robocopy "$installDir" "$backupDir" $flags >nul
set "rc=%ERRORLEVEL%"
if %rc% GEQ 8 (
  >>"%LOG%" echo [%DATE% %TIME%] Backup failed with robocopy code %rc% - update aborted, nothing changed.
  start "" "$exePath"
  exit /b 1
)

>>"%LOG%" echo [%DATE% %TIME%] Backup taken - applying the new build.
robocopy "$stagedDir" "$installDir" $flags >nul
set "rc=%ERRORLEVEL%"
if %rc% GEQ 8 (
  >>"%LOG%" echo [%DATE% %TIME%] Update failed with robocopy code %rc% - restoring the previous version.
  goto restore
)
rem Codes under 8 also cover a mirror that copied nothing, so confirm the
rem new build really landed before relaunching.
set "install_ok=1"
if not exist "$exePath" set "install_ok="
if not exist "$installedDll" set "install_ok="
if not exist "$installedData" set "install_ok="
if not defined install_ok (
  >>"%LOG%" echo [%DATE% %TIME%] Update left an incomplete install - restoring the previous version.
  goto restore
)

>>"%LOG%" echo [%DATE% %TIME%] Update applied - relaunching. Previous version retained at "$backupDir"
start "" "$exePath"
rem The backup deliberately survives. start only proves the process was
rem created, not that it stayed up, and nobody is watching this till: a
rem build that dies on a missing DLL must still have something to roll
rem back to. The next update reclaims this folder before taking its own
rem backup, so it costs one stale copy on disk and buys a one-folder
rem copy back to a working install.
rmdir /s /q "$stagedDir"
(goto) 2>nul & del "%~f0"
exit /b 0

:restore
robocopy "$backupDir" "$installDir" $flags >nul
set "rc=%ERRORLEVEL%"
if %rc% GEQ 8 (
  >>"%LOG%" echo [%DATE% %TIME%] Restore failed with robocopy code %rc% - the install is broken. Recover it by hand from "$backupDir"
  exit /b 2
)
start "" "$exePath"
exit /b 1
''';

  // A .bat is parsed by byte offset; cmd.exe mishandles LF-only files when
  // seeking `goto` labels and when reading multi-line parenthesised blocks,
  // which is exactly what this script is made of. Normalise first so the
  // conversion stays idempotent.
  return script.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
}
