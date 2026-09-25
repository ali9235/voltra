@echo off
rem Commits the working tree as Ali, and records what git actually did so the
rem result can be checked rather than assumed.

rem The repo root is one level up from tools\, wherever this was cloned.
cd /d "%~dp0.."
if not exist _logs mkdir _logs
title VOLTRA COMMIT
del /q _logs\_commit_done.txt >nul 2>&1

echo [1/4] clearing a stale git lock, if any ...
if exist .git\index.lock del /f /q .git\index.lock

echo [2/4] untracking what should never have been tracked ...
git rm --cached --quiet health_payload.json > _logs\commit.log 2>&1
git rm --cached --quiet _VOLTRA_FINISH.bat >> _logs\commit.log 2>&1
git rm -r --cached --quiet lib/__pycache__ >> _logs\commit.log 2>&1
rd /s /q lib\__pycache__ >nul 2>&1

echo [3/4] committing ...
git config user.name "Ali Shantti" >> _logs\commit.log 2>&1
git config user.email "alishantti85@gmail.com" >> _logs\commit.log 2>&1
git add -A >> _logs\commit.log 2>&1
git commit -F tools\_commit_message.txt >> _logs\commit.log 2>&1

echo --- LOG --- >> _logs\commit.log
git log --oneline -4 >> _logs\commit.log 2>&1
echo --- AUTHOR --- >> _logs\commit.log
git log -1 --pretty=format:"%%an <%%ae>" >> _logs\commit.log 2>&1
echo. >> _logs\commit.log
echo --- STATUS --- >> _logs\commit.log
git status --short >> _logs\commit.log 2>&1
echo --- TRACKED PAYLOAD (should be empty) --- >> _logs\commit.log
git ls-files health_payload.json _data >> _logs\commit.log 2>&1

echo [4/4] done.
echo DONE > _logs\_commit_done.txt
timeout /t 8 /nobreak >nul
