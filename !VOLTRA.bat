@echo off
rem Work from wherever this repo was cloned, not a path baked in on one PC.
cd /d "%~dp0"
if not exist _logs mkdir _logs
if not exist _data mkdir _data
title VOLTRA
cls
echo.
echo   ===========================================
echo                     V O L T R A
echo   ===========================================
echo.

echo   [1/3] Health server (port 8766) ...
curl -s -o nul -m 3 http://127.0.0.1:8766/health/summary
if %ERRORLEVEL%==0 goto server_ok

echo         Not answering. Clearing port 8766 ...
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8766" ^| findstr "LISTENING"') do taskkill /PID %%p /F >nul 2>&1
timeout /t 2 /nobreak >nul

rem A log file left locked by an earlier run used to make the start fail
rem silently. Fall back to another name instead of dying.
rem No spaces in these paths, so no nested quoting in the start line below.
set "SRVLOG=_logs\health_server.console.log"
del /q "%SRVLOG%" >nul 2>&1
if exist "%SRVLOG%" set "SRVLOG=_logs\health_server.console.%RANDOM%.log"

echo         Starting health server ...
start "VOLTRA HEALTH SERVER" cmd /c "python -u voltra_health_server.py > %SRVLOG% 2>&1"
set /a TRIES=0

:wait_server
timeout /t 2 /nobreak >nul
curl -s -o nul -m 3 http://127.0.0.1:8766/health/summary
if %ERRORLEVEL%==0 goto server_ok
set /a TRIES+=1
if %TRIES% LSS 15 goto wait_server
echo.
echo   !!  The health server did not answer.
echo       Open _logs\health_server.log to see why.
echo.
pause
exit /b 1

:server_ok
echo         OK  ->  http://127.0.0.1:8766/health/summary
echo.

rem --------------------------------------------------------------------------
rem VOLTRA is a native Windows app. It is not a web page, and it is not
rem something to look at inside Chrome or VS Code: the morning voice goes
rem through the Windows speech engine, which the browser build cannot reach.
rem
rem If a release build exists, launch that — it starts instantly and needs no
rem toolchain. Otherwise run the debug build, which needs Visual Studio 2022
rem Build Tools with the C++ workload. If those are missing, say so plainly
rem instead of quietly falling back to Chrome.
rem --------------------------------------------------------------------------

set "RELEASE_EXE=build\windows\x64\runner\Release\voltra_app.exe"

echo   [2/3] VOLTRA app (native Windows) ...

if exist "%RELEASE_EXE%" (
    echo         Launching the release build ...
    start "" "%RELEASE_EXE%"
    goto done
)

rem Flutter needs symlink support to build a project that uses plugins, and
rem Windows only allows symlinks without Administrator once Developer Mode is
rem on. This is the actual blocker on this PC — Visual Studio Build Tools 2022
rem are already installed. Checking the registry key is exact; checking for
rem cl.exe is not, because it only exists on PATH inside a VS developer prompt.
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense 2>nul | findstr /i "0x1" >nul
if %ERRORLEVEL%==0 goto run_debug

echo.
echo   !!  VOLTRA cannot build the native Windows app yet.
echo.
echo       Windows Developer Mode is off, and Flutter needs it to create the
echo       symlinks a plugin build requires.
echo.
echo       Turn it on:
echo         Settings ^> System ^> For developers ^> Developer Mode  ->  On
echo       or run:  start ms-settings:developers
echo.
echo       Then run this launcher again.
echo.
echo       The health server above is running, so your data is safe either way.
echo.
pause
exit /b 1

:run_debug
set "APPLOG=_logs\app.log"
del /q "%APPLOG%" >nul 2>&1
if exist "%APPLOG%" set "APPLOG=_logs\app.%RANDOM%.log"

echo         Building and starting. First build takes a few minutes ...
start "VOLTRA APP" cmd /c "flutter run -d windows > %APPLOG% 2>&1"
echo         Watch progress with:  type %APPLOG%
goto done

:done
echo.
echo   [3/3] VOLTRA is starting in its own window.
echo.
echo   Leave this window open while you use VOLTRA.
echo   Closing the VOLTRA windows stops it.
echo.
pause
