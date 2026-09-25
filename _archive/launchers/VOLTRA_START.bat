@echo off
cd /d "C:\Users\G I G A B Y T E\Documents\FlutterProjects\voltra_app"
if not exist _logs mkdir _logs
title VOLTRA BUILD AND TEST
echo ==== VOLTRA START ==== > _logs\00_master.log
echo %DATE% %TIME% >> _logs\00_master.log

echo [1/6] flutter --version
call flutter --version > _logs\01_version.log 2>&1

echo [2/6] flutter pub get
call flutter pub get > _logs\02_pubget.log 2>&1
echo pub get exit=%ERRORLEVEL% >> _logs\00_master.log

echo [3/6] flutter analyze
call flutter analyze > _logs\03_analyze.log 2>&1
echo analyze exit=%ERRORLEVEL% >> _logs\00_master.log

echo [4/6] python deps (flask, flask-cors)
python -m pip install --disable-pip-version-check flask flask-cors > _logs\04_pip.log 2>&1
echo pip exit=%ERRORLEVEL% >> _logs\00_master.log

echo [5/6] starting VOLTRA Desktop server
start "VOLTRA DESKTOP SERVER" _run_server.bat
timeout /t 6 /nobreak > nul
python voltra_selftest.py > _logs\06_selftest.log 2>&1
echo selftest exit=%ERRORLEVEL% >> _logs\00_master.log

echo [6/6] starting Flutter app in Chrome (port 5123)
start "VOLTRA COMPANION" _run_app.bat

echo ==== MASTER FINISHED ==== >> _logs\00_master.log
echo DONE > _logs\_done.txt
echo.
echo Finished. Logs are in the _logs folder.
timeout /t 15 /nobreak > nul
