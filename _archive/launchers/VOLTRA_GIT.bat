@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA GIT INIT
echo Initialising a local git repository (no push, no credentials used).
git init > _logs\40_git.log 2>&1
git add -A >> _logs\40_git.log 2>&1
git -c user.email="alishantti85@gmail.com" -c user.name="ali" commit -m "VOLTRA Companion: web + desktop pairing + iOS HealthKit integration" >> _logs\40_git.log 2>&1
git log --oneline >> _logs\40_git.log 2>&1
git status --short >> _logs\40_git.log 2>&1
echo Done. See _logs\40_git.log
timeout /t 12 /nobreak > nul
