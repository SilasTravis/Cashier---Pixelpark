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
/// destination, so the executable is checked for by name on both sides of
/// the apply.
///
/// The script is launched detached (no console), which is why it waits
/// with `ping` instead of `timeout` and why every diagnostic is appended
/// to %TEMP%\cashier_update.log instead of echoed to a console that
/// nobody will ever see.
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

  final script =
      '''
@echo off
setlocal
rem Never run from inside a folder we are about to mirror over.
cd /d "%TEMP%"
set "LOG=%TEMP%\\cashier_update.log"

set /a tries=0
:waitloop
tasklist /FI "PID eq $pid" /NH | find "$pid" >nul
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
rem unless the new executable is actually there.
if not exist "$stagedExe" (
  >>"%LOG%" echo [%DATE% %TIME%] Staged build has no $exeName - update aborted, nothing changed.
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

robocopy "$stagedDir" "$installDir" $flags >nul
set "rc=%ERRORLEVEL%"
if %rc% GEQ 8 (
  >>"%LOG%" echo [%DATE% %TIME%] Update failed with robocopy code %rc% - restoring the previous version.
  goto restore
)
rem Codes under 8 also cover a mirror that copied nothing, so confirm the
rem executable really landed before destroying the way back.
if not exist "$exePath" (
  >>"%LOG%" echo [%DATE% %TIME%] Update left no $exeName in the install folder - restoring the previous version.
  goto restore
)

start "" "$exePath"
rmdir /s /q "$backupDir"
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
