@echo off
rem Opens Windows Settings straight at the Developer Mode toggle.
rem
rem That toggle is the one thing standing between this project and a native
rem release build: Flutter needs Developer Mode to create the symlinks a plugin
rem build requires. Visual Studio Build Tools are already installed here.
rem
rem Nothing is changed by this script. It only opens the page - the switch has
rem to be flipped by hand.

title VOLTRA - Developer Mode
echo.
echo   Opening  Settings ^> System ^> For developers
echo.
echo   Turn ON "Developer Mode", accept the confirmation, then run
echo   !VOLTRA.bat  for the real native window.
echo.
start ms-settings:developers
timeout /t 6 /nobreak >nul
