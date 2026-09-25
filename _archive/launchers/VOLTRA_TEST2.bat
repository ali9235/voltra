@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA BROWSER CORS TEST
python voltra_browser_cors_test.py > _logs\08_browsercors.log 2>&1
echo exit=%ERRORLEVEL% >> _logs\08_browsercors.log
timeout /t 8 /nobreak > nul
