@echo off
rem The repo root is one level up from tools\, wherever this was cloned.
cd /d "%~dp0.."
if not exist _logs mkdir _logs
title VOLTRA DEV CHECK
echo RUNNING > _logs\_dev_done.txt
call flutter pub get > _logs\10_pubget.log 2>&1
call flutter analyze > _logs\11_analyze.log 2>&1
git config user.name "Ali Shantti" >> _logs\50_commit.log 2>&1
git config user.email "alishantti85@gmail.com" >> _logs\50_commit.log 2>&1
git add -A >> _logs\50_commit.log 2>&1
git commit -m "VOLTRA: context engine, dynamic theme, app shell, Health and Sleep modules" >> _logs\50_commit.log 2>&1
git log --oneline -3 >> _logs\50_commit.log 2>&1
call flutter doctor > _logs\12_doctor.log 2>&1
echo DONE > _logs\_dev_done.txt
timeout /t 5 /nobreak > nul
