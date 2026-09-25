@echo off
rem Bring VOLTRA up so Ali can actually look at it, and record what happened
rem so nothing has to be guessed at afterwards.
rem
rem   1. Health server on 8766, with the real summary captured to a log.
rem   2. Developer Mode check - the one switch between here and a native build.
rem   3. Native Windows app if it can be built; otherwise Settings is opened on
rem      the right page and the web build runs as a TEMPORARY view only.

rem The repo root is one level up from tools\, wherever this was cloned.
cd /d "%~dp0.."
if not exist _logs mkdir _logs
if not exist _data mkdir _data
title VOLTRA
cls

del /q _logs\_show_done.txt >nul 2>&1
del /q _logs\show_status.log >nul 2>&1
del /q _logs\show_summary.json >nul 2>&1

echo VOLTRA SHOW  %DATE% %TIME% > _logs\show_status.log

echo.
echo   ===========================================
echo                     V O L T R A
echo   ===========================================
echo.

rem -------------------------------------------------------------- health server
echo   [1/3] Health server (port 8766) ...
curl -s -o nul -m 3 http://127.0.0.1:8766/health/summary
if %ERRORLEVEL%==0 (
    echo SERVER=ALREADY_RUNNING >> _logs\show_status.log
    goto server_ok
)

echo         Not answering. Clearing port 8766 ...
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8766" ^| findstr "LISTENING"') do taskkill /PID %%p /F >nul 2>&1
timeout /t 2 /nobreak >nul

set "SRVLOG=_logs\health_server.console.log"
del /q "%SRVLOG%" >nul 2>&1
if exist "%SRVLOG%" set "SRVLOG=_logs\health_server.console.%RANDOM%.log"

echo         Starting health server ...
start "VOLTRA HEALTH SERVER" cmd /c "python -u voltra_health_server.py > %SRVLOG% 2>&1"
set /a TRIES=0

:wait_server
timeout /t 2 /nobreak >nul
curl -s -o nul -m 3 http://127.0.0.1:8766/health/summary
if %ERRORLEVEL%==0 (
    echo SERVER=STARTED >> _logs\show_status.log
    goto server_ok
)
set /a TRIES+=1
if %TRIES% LSS 15 goto wait_server

echo SERVER=FAILED >> _logs\show_status.log
echo.
echo   !!  The health server did not answer. See _logs\health_server.log
echo.
echo DONE > _logs\_show_done.txt
pause
exit /b 1

:server_ok
echo         OK  ->  http://127.0.0.1:8766/health/summary
rem Capture the real payload so the numbers on screen can be checked against it.
curl -s -m 5 http://127.0.0.1:8766/health/summary > _logs\show_summary.json 2>&1
echo.

rem ---------------------------------------------------------------- dev mode
echo   [2/3] Windows Developer Mode ...
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense 2>nul | findstr /i "0x1" >nul
if %ERRORLEVEL%==0 goto devmode_on

echo DEVMODE=OFF >> _logs\show_status.log
echo         OFF.
echo.
echo   ------------------------------------------------------------------
echo     VOLTRA cannot build the NATIVE Windows app until Developer Mode
echo     is on. Visual Studio Build Tools are already installed - this is
echo     the only switch left.
echo.
echo     Opening Settings on the right page now.
echo     Turn ON "Developer Mode", then run  !VOLTRA.bat
echo.
echo     What opens below is the TEMPORARY WEB VIEW so you can see the
echo     Morning Mode UI while waiting. It is NOT the finished native app,
echo     and the spoken greeting does NOT work there - the browser cannot
echo     reach the Windows speech voices.
echo   ------------------------------------------------------------------
echo.

start ms-settings:developers
timeout /t 3 /nobreak >nul

echo   [3/3] Temporary web view (port 5123) ...
set "APPLOG=_logs\app_web.log"
del /q "%APPLOG%" >nul 2>&1
if exist "%APPLOG%" set "APPLOG=_logs\app_web.%RANDOM%.log"

start "VOLTRA WEB (TEMPORARY VIEW)" cmd /c "flutter run -d chrome --web-port 5123 > %APPLOG% 2>&1"
set /a TRIES=0

:wait_web
timeout /t 5 /nobreak >nul
curl -s -o nul -m 3 http://127.0.0.1:5123
if %ERRORLEVEL%==0 (
    echo WEB=UP >> _logs\show_status.log
    goto shown
)
set /a TRIES+=1
if %TRIES% LSS 48 goto wait_web

echo WEB=FAILED >> _logs\show_status.log
goto shown

:devmode_on
echo DEVMODE=ON >> _logs\show_status.log
echo         ON.
echo.
echo   [3/3] Native Windows app ...

set "RELEASE_EXE=build\windows\x64\runner\Release\voltra_app.exe"
if exist "%RELEASE_EXE%" (
    echo         Launching the existing release build ...
    echo NATIVE=RELEASE_EXE >> _logs\show_status.log
    start "" "%RELEASE_EXE%"
    goto shown
)

echo         Building the release app. First build takes a few minutes ...
set "BUILDLOG=_logs\show_build.log"
del /q "%BUILDLOG%" >nul 2>&1
call flutter build windows --release > "%BUILDLOG%" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> _logs\show_status.log

if exist "%RELEASE_EXE%" (
    echo         Built. Launching ...
    echo NATIVE=BUILT_AND_LAUNCHED >> _logs\show_status.log
    start "" "%RELEASE_EXE%"
    goto shown
)

echo NATIVE=BUILD_FAILED >> _logs\show_status.log
echo.
echo   !!  The release build did not produce an exe. See _logs\show_build.log
echo.

:shown
echo. >> _logs\show_status.log
echo DONE > _logs\_show_done.txt
echo.
echo   Leave this window open while you use VOLTRA.
echo.
timeout /t 30 /nobreak >nul
