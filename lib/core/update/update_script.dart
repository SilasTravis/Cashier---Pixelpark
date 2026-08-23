/// Builds the batch script that replaces the install folder after the app
/// exits. Kept as a pure function so its exact text is testable — this is
/// the one part of the updater that runs outside Dart, where a mistake
/// means a broken install on a POS machine.
///
/// `robocopy /MIR` rather than a folder rename: rename fails when the
/// staging folder (under %APPDATA%) and the install folder live on
/// different drives. Note that /MIR mirrors — anything in the install
/// folder that isn't part of the new build is removed.
String buildUpdateScript({
  required int pid,
  required String installDir,
  required String stagedDir,
  required String backupDir,
  required String exePath,
}) {
  const flags = '/MIR /R:2 /W:1 /NFL /NDL /NJH /NJS';
  return '''
@echo off
setlocal
rem Never run from inside a folder we're about to mirror over.
cd /d "%TEMP%"

set /a tries=0
:waitloop
tasklist /FI "PID eq $pid" /NH | find "$pid" >nul
if errorlevel 1 goto gone
set /a tries+=1
if %tries% GEQ 60 (
  echo Cashier still running after 60s - update aborted, nothing changed.
  exit /b 1
)
timeout /t 1 /nobreak >nul
goto waitloop

:gone
if exist "$backupDir" rmdir /s /q "$backupDir"
robocopy "$installDir" "$backupDir" $flags >nul
if %ERRORLEVEL% GEQ 8 (
  echo Backup failed - update aborted.
  start "" "$exePath"
  exit /b 1
)

robocopy "$stagedDir" "$installDir" $flags >nul
if %ERRORLEVEL% GEQ 8 (
  echo Update failed - restoring the previous version.
  robocopy "$backupDir" "$installDir" $flags >nul
  start "" "$exePath"
  exit /b 1
)

start "" "$exePath"
rmdir /s /q "$backupDir"
rmdir /s /q "$stagedDir"
(goto) 2>nul & del "%~f0"
''';
}
