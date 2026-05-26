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
echo [1/4] Building Flutter Windows Release...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [ERROR] Build failed, check errors above
    pause
    exit /b 1
)
echo [1/4] Build complete

:: Prepare output directory
echo.
echo [2/4] Preparing output directory...
if exist smart_assistant_windows_release (
    rmdir /s /q smart_assistant_windows_release
)
mkdir smart_assistant_windows_release
echo [2/4] Output directory ready

:: Copy build artifacts
echo.
echo [3/4] Copying build artifacts...
xcopy /e /i /q /y build\windows\x64\runner\Release\* smart_assistant_windows_release\ >nul
if %errorlevel% neq 0 (
    echo [WARN] Copy may be incomplete, check build\windows\x64\runner\Release\
)
echo [3/4] Copy complete

:: Copy data files (cmake INSTALL often fails in sandbox, losing app.so + flutter_assets)
echo.
echo [4/4] Copying data files (app.so + flutter_assets)...
if not exist smart_assistant_windows_release\data mkdir smart_assistant_windows_release\data
if not exist smart_assistant_windows_release\data\flutter_assets mkdir smart_assistant_windows_release\data\flutter_assets
xcopy /e /i /q /y build\flutter_assets\* smart_assistant_windows_release\data\flutter_assets\ >nul
copy /y build\windows\app.so smart_assistant_windows_release\data\app.so >nul
if exist build\windows\x64\runner\Release\data\icudtl.dat (
    copy /y build\windows\x64\runner\Release\data\icudtl.dat smart_assistant_windows_release\data\icudtl.dat >nul
)
echo [4/4] Data copy complete

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