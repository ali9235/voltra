@echo off
rem VOLTRA verification run.
rem
rem Runs the three checks that decide whether this project is actually healthy
rem — analyze, test, release build — each into its own log, and writes a
rem sentinel file at the end so a watcher knows it finished rather than
rem guessing from a half-written log.
rem
rem Nothing here is allowed to lie about a result: every step records its own
rem exit code, and the summary at the bottom prints those codes verbatim.

rem The repo root is one level up from tools\, wherever this was cloned.
cd /d "%~dp0.."
if not exist _logs mkdir _logs
if not exist _data mkdir _data
title VOLTRA VERIFY

del /q _logs\_verify_done.txt >nul 2>&1
del /q _logs\verify_*.log >nul 2>&1

echo [0/5] housekeeping ...
rem A Python cache folder had ended up inside lib/, where Dart sources live.
rd /s /q lib\__pycache__ >nul 2>&1
del /q lib\*.pyc >nul 2>&1

rem The health payload used to be tracked by git. Stop tracking it (the file
rem itself stays on disk) and drop the launcher that was deleted earlier.
git rm --cached --quiet health_payload.json >nul 2>&1
git rm --cached --quiet _VOLTRA_FINISH.bat >nul 2>&1
git rm -r --cached --quiet lib/__pycache__ >nul 2>&1

echo [1/5] flutter --version ...
call flutter --version > _logs\verify_00_version.log 2>&1

echo [1b/5] flutter doctor ...
call flutter doctor > _logs\verify_00_doctor.log 2>&1

echo [2/5] flutter pub get ...
call flutter pub get > _logs\verify_01_pubget.log 2>&1
set PUBGET=%ERRORLEVEL%

echo [3/5] flutter analyze ...
call flutter analyze > _logs\verify_02_analyze.log 2>&1
set ANALYZE=%ERRORLEVEL%

echo [4/5] flutter test ...
call flutter test > _logs\verify_03_test.log 2>&1
set TESTS=%ERRORLEVEL%

echo [5/5] flutter build windows --release ...
call flutter build windows --release > _logs\verify_04_build.log 2>&1
set BUILD=%ERRORLEVEL%

echo. > _logs\verify_99_summary.log
echo pub get exit code : %PUBGET%  >> _logs\verify_99_summary.log
echo analyze exit code : %ANALYZE% >> _logs\verify_99_summary.log
echo test exit code    : %TESTS%   >> _logs\verify_99_summary.log
echo build exit code   : %BUILD%   >> _logs\verify_99_summary.log
echo. >> _logs\verify_99_summary.log
if exist "build\windows\x64\runner\Release\voltra_app.exe" (
    echo release exe      : PRESENT >> _logs\verify_99_summary.log
) else (
    echo release exe      : MISSING >> _logs\verify_99_summary.log
)

echo DONE > _logs\_verify_done.txt

echo.
echo   ---- VOLTRA VERIFY FINISHED ----
type _logs\verify_99_summary.log
echo.
echo   Logs are in _logs\verify_*.log
echo.
timeout /t 20 /nobreak >nul
