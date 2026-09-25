@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA HEALTH SERVER RESTART
echo RUNNING > _logs\_srv_done.txt
netstat -ano | findstr ":8766" > _logs\20_ports.log 2>&1
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8766" ^| findstr "LISTENING"') do taskkill /PID %%p /F >> _logs\21_kill.log 2>&1
timeout /t 3 /nobreak > nul
start "VOLTRA HEALTH SERVER" _run_server.bat
timeout /t 8 /nobreak > nul
echo DONE > _logs\_srv_done.txt
