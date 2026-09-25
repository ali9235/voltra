@echo off
rem Work from wherever this repo was cloned, not a path baked in on one PC.
cd /d "%~dp0"
title VOLTRA - Windows build setup
cls
echo.
echo   Building a native Windows app needs two things:
echo.
echo     1. Windows Developer Mode, so Flutter can create the symlinks a
echo        plugin build requires.
echo     2. Visual Studio 2022 Build Tools (C++ desktop workload).
echo.
echo   On this PC the Build Tools are already installed, so this will only
echo   turn on Developer Mode and skip the large download.
echo.
echo   Windows will now ask for Administrator permission.
echo   Click YES on the prompt. That prompt cannot be clicked for you -
echo   Windows blocks automated input on it by design.
echo.
timeout /t 3 /nobreak >nul
powershell -NoProfile -Command "Start-Process -FilePath '%~dp0tools\_vs_setup_elevated.bat' -Verb RunAs"
echo.
echo   Setup is running in its own window. You can close this one.
timeout /t 8 /nobreak >nul
