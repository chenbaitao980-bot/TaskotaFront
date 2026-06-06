@echo off
setlocal enabledelayedexpansion

:: Kill any running Taskora processes that may lock files in the output
taskkill /f /im Taskora.exe >nul 2>&1
timeout /t 1 /nobreak >nul

cd /d "%~dp0"

echo ========================================
echo  Taskora - Windows Build Script
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

:: Robust cleanup ¡ª retry and fall back to rename if files are locked
if exist Taskora_windows_release (
    attrib -r Taskora_windows_release\*.* /s /d >nul 2>&1
    rmdir /s /q Taskora_windows_release >nul 2>&1
    if exist Taskora_windows_release (
        echo [WARN] Cleanup blocked by locked files, retrying after 2s...
        timeout /t 2 /nobreak >nul
        rmdir /s /q Taskora_windows_release >nul 2>&1
    )
    if exist Taskora_windows_release (
        ren Taskora_windows_release "Taskora_windows_release_%RANDOM%" >nul 2>&1
    )
)
mkdir Taskora_windows_release
echo [2/4] Output directory ready

:: Copy build artifacts
echo.
echo [3/4] Copying build artifacts...
xcopy /e /i /q /y build\windows\x64\runner\Release\* Taskora_windows_release\ >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARN] xcopy had issues, trying robocopy as fallback...
    robocopy "build\windows\x64\runner\Release" Taskora_windows_release /e /np /nfl /ndl /njh /njs /r:0 /w:0 >nul 2>&1
    if %errorlevel% geq 8 (
        echo [WARN] Copy may be incomplete, check build\windows\x64\runner\Release\
    )
)
echo [3/4] Copy complete

:: Copy data files (cmake INSTALL often fails in sandbox, losing app.so + flutter_assets)
echo.
echo [4/4] Copying data files (app.so + flutter_assets)...
if not exist Taskora_windows_release\data mkdir Taskora_windows_release\data
if not exist Taskora_windows_release\data\flutter_assets mkdir Taskora_windows_release\data\flutter_assets
xcopy /e /i /q /y build\flutter_assets\* Taskora_windows_release\data\flutter_assets\ >nul
copy /y build\windows\app.so Taskora_windows_release\data\app.so >nul
if exist build\windows\x64\runner\Release\data\icudtl.dat (
    copy /y build\windows\x64\runner\Release\data\icudtl.dat Taskora_windows_release\data\icudtl.dat >nul
)
echo [4/4] Data copy complete

:: Write version file
echo %VERSION% > Taskora_windows_release\version.txt

echo.
echo ========================================
echo  Build Complete!
echo  Version: %VERSION%
echo  Output: Taskora_windows_release\
echo ========================================

endlocal
pause
