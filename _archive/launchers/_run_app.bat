@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA COMPANION - FLUTTER RUN
call flutter run -d chrome --web-port 5123 > _logs\07_flutterrun.log 2>&1
echo FLUTTER RUN EXITED >> _logs\07_flutterrun.log
pause
