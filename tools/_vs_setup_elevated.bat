@echo off
rem Runs elevated, from !INSTALL_WINDOWS_BUILD.bat.
rem
rem Two things are needed to build a native Flutter Windows app here:
rem   1. Windows Developer Mode, so Flutter can create the symlinks a plugin
rem      build needs without Administrator.
rem   2. Visual Studio 2022 Build Tools with the C++ desktop workload.
rem
rem Step 2 is skipped when the Build Tools are already installed, so re-running
rem this to fix Developer Mode does not trigger a multi-gigabyte download for
rem nothing.

rem The repo root is one level up from tools\, wherever this was cloned.
cd /d "%~dp0.."
if not exist _logs mkdir _logs
title VOLTRA - WINDOWS BUILD SETUP (Administrator)
echo VOLTRA Windows build setup > _logs\vs_install.log
echo %DATE% %TIME% >> _logs\vs_install.log

echo.
echo   Step 1 of 2 - Enabling Windows Developer Mode ...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v AllowDevelopmentWithoutDevLicense /d 1 >> _logs\vs_install.log 2>&1
echo         devmode exit=%ERRORLEVEL% >> _logs\vs_install.log

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense 2>nul | findstr /i "0x1" >nul
if %ERRORLEVEL%==0 (
    echo         Developer Mode is ON.
    echo DEVMODE=ON >> _logs\vs_install.log
) else (
    echo         Developer Mode could NOT be enabled from here.
    echo         Turn it on by hand: Settings ^> System ^> For developers.
    echo DEVMODE=OFF >> _logs\vs_install.log
)

echo.
echo   Step 2 of 2 - Visual Studio 2022 Build Tools ^(C++ desktop workload^)

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" goto install_buildtools

"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath > "%TEMP%\voltra_vs_path.txt" 2>nul
for /f "usebackq delims=" %%i in ("%TEMP%\voltra_vs_path.txt") do set "VSPATH=%%i"
del /q "%TEMP%\voltra_vs_path.txt" >nul 2>&1

if defined VSPATH (
    echo         Already installed at %VSPATH% - skipping the download.
    echo BUILDTOOLS=ALREADY_PRESENT %VSPATH% >> _logs\vs_install.log
    goto finished
)

:install_buildtools
echo         Downloading the installer ...
curl -L -s -o "%TEMP%\vs_BuildTools.exe" https://aka.ms/vs/17/release/vs_BuildTools.exe
echo         download exit=%ERRORLEVEL% >> _logs\vs_install.log
if not exist "%TEMP%\vs_BuildTools.exe" goto failed

echo         Installing. This is a large download and will take a while.
echo         A progress window will appear. Do not close it.
echo INSTALL STARTED %TIME% >> _logs\vs_install.log
"%TEMP%\vs_BuildTools.exe" --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --norestart --wait >> _logs\vs_install.log 2>&1
echo INSTALL EXIT=%ERRORLEVEL% %TIME% >> _logs\vs_install.log

:finished
echo DONE > _logs\_vs_done.txt
echo.
echo   Finished. See _logs\vs_install.log
echo   Now run  !VOLTRA.bat  again.
timeout /t 12 /nobreak >nul
exit /b 0

:failed
echo FAILED TO DOWNLOAD >> _logs\vs_install.log
echo FAILED > _logs\_vs_done.txt
echo   Could not download the installer.
pause
