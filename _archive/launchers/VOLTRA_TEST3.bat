@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA DART TESTS
call flutter test > _logs\09_fluttertest.log 2>&1
echo exit=%ERRORLEVEL% >> _logs\09_fluttertest.log
call flutter analyze > _logs\10_analyze2.log 2>&1
echo exit=%ERRORLEVEL% >> _logs\10_analyze2.log
echo TESTS DONE > _logs\_tests_done.txt
timeout /t 10 /nobreak > nul
