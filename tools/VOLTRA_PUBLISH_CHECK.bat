@echo off
rem Pre-publication check.
rem
rem Formats, analyzes, tests, attempts the release build, and reports whether
rem the GitHub CLI is installed and logged in. Everything lands in _logs\ so the
rem results can be read rather than guessed at. Nothing is pushed here.

rem The repo root is one level up from tools\, wherever this was cloned.
cd /d "%~dp0.."
if not exist _logs mkdir _logs
title VOLTRA PUBLISH CHECK

del /q _logs\_publish_done.txt >nul 2>&1
del /q _logs\pub_*.log >nul 2>&1

echo [0/7] housekeeping ...
rem A stale index.lock from an interrupted git run blocks every later command.
if exist .git\index.lock del /f /q .git\index.lock
rd /s /q lib\__pycache__ >nul 2>&1

rem This file held an absolute cmake path from one machine. Untrack it; the new
rem .gitignore keeps it out from here on. The file stays on disk.
git rm --cached --quiet .vscode/settings.json > _logs\pub_00_untrack.log 2>&1

echo [1/7] git branch ...
git branch --show-current > _logs\pub_01_branch.log 2>&1

echo [2/7] dart format ...
call dart format lib test > _logs\pub_02_format.log 2>&1
set FMT=%ERRORLEVEL%

echo [3/7] flutter analyze ...
call flutter analyze > _logs\pub_03_analyze.log 2>&1
set ANALYZE=%ERRORLEVEL%

echo [4/7] flutter test ...
call flutter test > _logs\pub_04_test.log 2>&1
set TESTS=%ERRORLEVEL%

echo [5/7] flutter build windows --release ...
call flutter build windows --release > _logs\pub_05_build.log 2>&1
set BUILD=%ERRORLEVEL%

echo [6/7] GitHub CLI ...
where gh > _logs\pub_06_gh.log 2>&1
echo --- gh --version --- >> _logs\pub_06_gh.log
call gh --version >> _logs\pub_06_gh.log 2>&1
echo --- gh auth status --- >> _logs\pub_06_gh.log
call gh auth status >> _logs\pub_06_gh.log 2>&1
echo --- gh auth exit code: %ERRORLEVEL% --- >> _logs\pub_06_gh.log

echo [7/7] git status ...
echo --- git status --short --- > _logs\pub_07_status.log 2>&1
git status --short >> _logs\pub_07_status.log 2>&1
echo --- files git would add (dry run) --- >> _logs\pub_07_status.log
git add -A --dry-run >> _logs\pub_07_status.log 2>&1

echo. > _logs\pub_99_summary.log
echo format exit code  : %FMT%     >> _logs\pub_99_summary.log
echo analyze exit code : %ANALYZE% >> _logs\pub_99_summary.log
echo test exit code    : %TESTS%   >> _logs\pub_99_summary.log
echo build exit code   : %BUILD%   >> _logs\pub_99_summary.log
if exist "build\windows\x64\runner\Release\voltra_app.exe" (
    echo release exe       : PRESENT >> _logs\pub_99_summary.log
) else (
    echo release exe       : MISSING >> _logs\pub_99_summary.log
)

echo DONE > _logs\_publish_done.txt

echo.
echo   ---- PUBLISH CHECK FINISHED ----
type _logs\pub_99_summary.log
echo.
timeout /t 20 /nobreak >nul
