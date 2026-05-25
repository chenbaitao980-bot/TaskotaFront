@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo ========================================
echo  Smart Assistant - Windows Build Script
echo ========================================

:: Read version from pubspec.yaml
for /f "tokens=2 delims= " %%a in ('findstr /b "version:" pubspec.yaml') do set VERSION=%%a
if "%VERSION%"=="" (
    echo [ERROR] Cannot read version from pubspec.yaml
    pause
    exit /b 1
)
echo Version: %VERSION%

:: Build Flutter Windows Release
echo.
echo [1/3] Building Flutter Windows Release...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [ERROR] Build failed, check errors above
    pause
    exit /b 1
)
echo [1/3] Build complete

:: Prepare output directory
echo.
echo [2/3] Preparing output directory...
if exist smart_assistant_windows_release (
    rmdir /s /q smart_assistant_windows_release
)
mkdir smart_assistant_windows_release
echo [2/3] Output directory ready

:: Copy build artifacts
echo.
echo [3/3] Copying build artifacts...
xcopy /e /i /q /y build\windows\x64\runner\Release\* smart_assistant_windows_release\ >nul
if %errorlevel% neq 0 (
    echo [WARN] Copy may be incomplete, check build\windows\x64\runner\Release\
)
echo [3/3] Copy complete

:: Write version file
echo %VERSION% > smart_assistant_windows_release\version.txt

echo.
echo ========================================
echo  Build Complete!
echo  Version: %VERSION%
echo  Output: smart_assistant_windows_release\
echo ========================================

endlocal
pause