@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA DESKTOP SERVER
python -u voltra_desktop_server_with_summary.py > _logs\health_server.log 2>&1
echo SERVER EXITED >> _logs\health_server.log
pause
