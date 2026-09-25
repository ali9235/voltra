@echo off
rem The repo root is one level up from tools\, wherever this was cloned.
cd /d "%~dp0.."
if not exist _logs mkdir _logs
title VOLTRA ADD IOS PLATFORM
echo [1/2] flutter create --platforms=ios .
call flutter create --platforms=ios . > _logs\20_create_ios.log 2>&1
echo exit=%ERRORLEVEL% >> _logs\20_create_ios.log
echo [2/2] flutter pub get
call flutter pub get > _logs\21_pubget_ios.log 2>&1
echo exit=%ERRORLEVEL% >> _logs\21_pubget_ios.log
echo IOS ADDED > _logs\_ios_done.txt
timeout /t 8 /nobreak > nul
