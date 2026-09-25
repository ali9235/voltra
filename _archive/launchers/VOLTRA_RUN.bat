@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA RUN ALL
start "VOLTRA HEALTH SERVER" _run_server.bat
timeout /t 5 /nobreak > nul
start "VOLTRA COMPANION" _run_app.bat
timeout /t 5 /nobreak > nul
