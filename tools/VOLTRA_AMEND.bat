@echo off
rem Folds the latest documentation edits into the single publish commit.
rem Safe: nothing has been pushed yet, and pre-publish-history is untouched.

cd /d "%~dp0.."
if not exist _logs mkdir _logs
title VOLTRA AMEND
if exist .git\index.lock del /f /q .git\index.lock

git add -A > _logs\amend.log 2>&1
git -c user.name="Ali Shantti" -c user.email="alishantti85@gmail.com" commit --amend -F tools\_commit_message.txt >> _logs\amend.log 2>&1

echo --- LOG --- >> _logs\amend.log
git log --oneline --all >> _logs\amend.log 2>&1
echo --- SHA --- >> _logs\amend.log
git log -1 --pretty=format:"%%H %%an <%%ae>" >> _logs\amend.log 2>&1
echo. >> _logs\amend.log
echo --- STATUS --- >> _logs\amend.log
git status --short >> _logs\amend.log 2>&1
echo --- PAYLOAD ON MAIN --- >> _logs\amend.log
git rev-list --objects main > "%TEMP%\vobj.txt" 2>nul
findstr /i "health_payload" "%TEMP%\vobj.txt" >> _logs\amend.log 2>&1
if errorlevel 1 (echo ABSENT >> _logs\amend.log) else (echo STILL_PRESENT >> _logs\amend.log)
del /q "%TEMP%\vobj.txt" >nul 2>&1

echo DONE > _logs\_amend_done.txt
timeout /t 8 /nobreak >nul
