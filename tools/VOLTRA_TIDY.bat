@echo off
rem The repo root is one level up from tools\, wherever this was cloned.
cd /d "%~dp0.."
if not exist _logs mkdir _logs
title VOLTRA TIDY
del /q _logs\_tidy_done.txt >nul 2>&1
echo RUNNING > _logs\_tidy_running.txt

echo [1/7] stopping the old health server ...
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8766" ^| findstr "LISTENING"') do taskkill /PID %%p /F >nul 2>&1
timeout /t 2 /nobreak >nul

echo [2/7] removing folders that moved ...
if exist _old_launchers rmdir /s /q _old_launchers
if exist __pycache__ rmdir /s /q __pycache__
if exist lib\features\home\widgets rmdir /s /q lib\features\home\widgets

echo [3/7] clearing stale logs ...
del /q _logs\*.log >nul 2>&1
del /q _logs\_*.txt >nul 2>&1
echo RUNNING > _logs\_tidy_running.txt

echo [4/7] flutter pub get ...
call flutter pub get > _logs\tidy_01_pubget.log 2>&1
echo exit=%ERRORLEVEL% >> _logs\tidy_01_pubget.log

echo [5/7] flutter analyze ...
call flutter analyze > _logs\tidy_02_analyze.log 2>&1
echo exit=%ERRORLEVEL% >> _logs\tidy_02_analyze.log

echo [6/7] committing ...
git config user.name "Ali Shantti" > _logs\tidy_03_commit.log 2>&1
git config user.email "alishantti85@gmail.com" >> _logs\tidy_03_commit.log 2>&1
git add -A >> _logs\tidy_03_commit.log 2>&1
git commit -m "Tidy: one canonical health server, one launcher, robust rotating logs, no zeros in place of missing data" >> _logs\tidy_03_commit.log 2>&1
git log --oneline -3 >> _logs\tidy_03_commit.log 2>&1
git status --short >> _logs\tidy_03_commit.log 2>&1

echo [7/7] flutter doctor ...
call flutter doctor > _logs\tidy_04_doctor.log 2>&1

del /q _logs\_tidy_running.txt >nul 2>&1
echo DONE > _logs\_tidy_done.txt
echo.
echo   Done. This window closes by itself.
timeout /t 6 /nobreak >nul
