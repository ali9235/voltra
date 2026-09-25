@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA VERIFY IOS + WEB
echo [1/3] flutter pub get
call flutter pub get > _logs\30_pubget.log 2>&1
echo [2/3] flutter analyze (compiles the HealthKit code too)
call flutter analyze > _logs\31_analyze.log 2>&1
echo analyze exit=%ERRORLEVEL% >> _logs\31_analyze.log
echo [3/3] flutter build web --release
call flutter build web --release > _logs\32_buildweb.log 2>&1
echo buildweb exit=%ERRORLEVEL% >> _logs\32_buildweb.log
echo VERIFY DONE > _logs\_verify_done.txt
timeout /t 10 /nobreak > nul
