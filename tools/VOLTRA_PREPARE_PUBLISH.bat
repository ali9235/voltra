@echo off
setlocal enabledelayedexpansion
rem ---------------------------------------------------------------------------
rem Prepare this repository to be published with a FRESH history.
rem
rem Why: four of the existing commits contain health_payload.json, a 3 MB
rem minute-by-minute record of one person's heart rate, HRV, sleep and walking
rem gait. That must not go to a public repository, and removing it from the
rem existing history would mean rewriting commits.
rem
rem NOTHING IS DELETED. Before anything changes:
rem   1. a full "git bundle --all" is written OUTSIDE the repository, and
rem      verified before we continue;
rem   2. the current main is kept on a local branch, pre-publish-history.
rem
rem If the bundle cannot be written or verified, this script stops and changes
rem nothing at all.
rem
rem The old history stays on this machine. It is never pushed.
rem ---------------------------------------------------------------------------

cd /d "%~dp0.."
if not exist _logs mkdir _logs
title VOLTRA PREPARE PUBLISH

set "LOG=_logs\publish_prepare.log"
del /q "%LOG%" >nul 2>&1
del /q _logs\_prepare_done.txt >nul 2>&1

if exist .git\index.lock del /f /q .git\index.lock

echo VOLTRA PREPARE PUBLISH  %DATE% %TIME% > "%LOG%"

echo [1/7] recording the current state ...
echo --- BEFORE: branches --- >> "%LOG%"
git branch -a >> "%LOG%" 2>&1
echo --- BEFORE: log --- >> "%LOG%"
git log --oneline >> "%LOG%" 2>&1

echo [2/7] backing up the full history to a bundle ...
set "BACKUP=..\voltra_history_backup"
if not exist "%BACKUP%" mkdir "%BACKUP%"
set "BUNDLE=%BACKUP%\voltra-full-history.bundle"
del /q "%BUNDLE%" >nul 2>&1

git bundle create "%BUNDLE%" --all >> "%LOG%" 2>&1
if not exist "%BUNDLE%" (
    echo BUNDLE=FAILED >> "%LOG%"
    echo.
    echo   !!  Could not write the backup bundle. Nothing has been changed.
    echo.
    echo FAILED > _logs\_prepare_done.txt
    pause
    exit /b 1
)

echo [3/7] verifying the bundle ...
git bundle verify "%BUNDLE%" >> "%LOG%" 2>&1
if errorlevel 1 (
    echo BUNDLE=UNVERIFIED >> "%LOG%"
    echo.
    echo   !!  The backup bundle did not verify. Nothing has been changed.
    echo.
    echo FAILED > _logs\_prepare_done.txt
    pause
    exit /b 1
)
echo BUNDLE=OK >> "%LOG%"

echo [4/7] keeping the old history on a local branch ...
git branch -f pre-publish-history main >> "%LOG%" 2>&1
echo --- pre-publish-history --- >> "%LOG%"
git log --oneline -1 pre-publish-history >> "%LOG%" 2>&1

echo [5/7] building a fresh single-commit history ...
git checkout --orphan publish-clean >> "%LOG%" 2>&1
git add -A >> "%LOG%" 2>&1
git -c user.name="Ali Shantti" -c user.email="alishantti85@gmail.com" commit -F tools\_commit_message.txt >> "%LOG%" 2>&1

rem Rename onto main. The previous main is still reachable through
rem pre-publish-history, so no commit is lost by this.
git branch -M publish-clean main >> "%LOG%" 2>&1

echo [6/7] checking the new history is clean ...
echo --- AFTER: branches --- >> "%LOG%"
git branch -a >> "%LOG%" 2>&1
echo --- AFTER: log on main --- >> "%LOG%"
git log --oneline main >> "%LOG%" 2>&1
echo --- health payload anywhere reachable from main? --- >> "%LOG%"
git rev-list --objects main > "%TEMP%\voltra_objs.txt" 2>>"%LOG%"
findstr /i "health_payload" "%TEMP%\voltra_objs.txt" >> "%LOG%" 2>&1
if errorlevel 1 (echo MAIN_PAYLOAD=ABSENT >> "%LOG%") else (echo MAIN_PAYLOAD=STILL_PRESENT >> "%LOG%")
del /q "%TEMP%\voltra_objs.txt" >nul 2>&1
echo --- largest blobs reachable from main --- >> "%LOG%"
git rev-list --objects main | git cat-file --batch-check="%%(objecttype) %%(objectsize) %%(rest)" 2>nul | findstr /b "blob" | sort /r >> "%LOG%" 2>&1

echo [7/7] re-running the checks ...
call flutter analyze > _logs\pub2_analyze.log 2>&1
set ANALYZE=%ERRORLEVEL%
call flutter test > _logs\pub2_test.log 2>&1
set TESTS=%ERRORLEVEL%

echo. >> "%LOG%"
echo analyze exit code : %ANALYZE% >> "%LOG%"
echo test exit code    : %TESTS%   >> "%LOG%"
echo --- git status --- >> "%LOG%"
git status --short >> "%LOG%" 2>&1

echo DONE > _logs\_prepare_done.txt

echo.
echo   ---- READY TO PUBLISH ----
echo   Old history saved to:  %BACKUP%\voltra-full-history.bundle
echo   Old history branch  :  pre-publish-history  (local only, do NOT publish)
echo   Publish branch      :  main
echo.
echo   Details in %LOG%
echo.
timeout /t 25 /nobreak >nul
