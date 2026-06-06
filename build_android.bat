@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo =============================================
echo  Taskora - Android Build Script
echo =============================================
echo.

:: Read version from pubspec.yaml
for /f "tokens=2 delims= " %%a in ('findstr /b "version:" pubspec.yaml') do set VERSION=%%a
if "%VERSION%"=="" (
    echo [ERROR] Cannot read version from pubspec.yaml
    pause
    exit /b 1
)
echo Version: %VERSION%
echo.

:: === Select build type ===
echo Select build type:
echo   [1] Debug APK  ^(fast, for testing^)
echo   [2] Release APK ^(needs signing config^)
echo   [3] Release App Bundle ^(.aab, for Play Store^)
echo.
set /p BUILD_TYPE="Enter choice (1/2/3, default=1): "
if "%BUILD_TYPE%"=="" set BUILD_TYPE=1

if "%BUILD_TYPE%"=="1" (
    set BUILD_MODE=debug
    set BUILD_CMD=flutter build apk --debug
    set OUTPUT_DIR=android_build_debug
) else if "%BUILD_TYPE%"=="2" (
    set BUILD_MODE=release
    set BUILD_CMD=flutter build apk --release
    set OUTPUT_DIR=android_build_release
) else if "%BUILD_TYPE%"=="3" (
    set BUILD_MODE=release
    set BUILD_CMD=flutter build appbundle --release
    set OUTPUT_DIR=android_build_aab
) else (
    echo [ERROR] Invalid choice
    pause
    exit /b 1
)
echo Selected: %BUILD_MODE%
echo.

:: === Optional: Clean ===
echo.
set /p DO_CLEAN="Run flutter clean first? (y/n, default=n): "
if /i "!DO_CLEAN!"=="y" (
    echo [1/5] Cleaning previous build...
    call flutter clean
    if !errorlevel! neq 0 (
        echo [ERROR] flutter clean failed
        pause
        exit /b 1
    )
    echo [OK]
) else (
    echo Skipping flutter clean
)

:: === Optional: Pub get ===
echo.
set /p DO_PUBGET="Run flutter pub get? (y/n, default=n): "
if /i "!DO_PUBGET!"=="y" (
    echo [2/5] Getting dependencies...
    call flutter pub get
    if !errorlevel! neq 0 (
        echo [ERROR] flutter pub get failed
        pause
        exit /b 1
    )
    echo [OK]
) else (
    echo Skipping flutter pub get
)

:: === Optional: Build runner ===
echo.
set /p DO_BUILDRUNNER="Run build_runner ^(re-generate models^)? (y/n, default=n): "
if /i "!DO_BUILDRUNNER!"=="y" (
    echo [3/5] Running build_runner...
    call dart run build_runner build --delete-conflicting-outputs
    if !errorlevel! neq 0 (
        echo [ERROR] build_runner failed
        pause
        exit /b 1
    )
    echo [OK]
) else (
    echo Skipping build_runner
)

:: === Build ===
echo.
echo [Building] %BUILD_CMD% ...
echo.
call %BUILD_CMD%
if !errorlevel! neq 0 (
    echo [ERROR] Build failed, check errors above
    pause
    exit /b 1
)
echo [OK] Build succeeded

:: === Copy artifacts ===
echo.
echo [Output] Preparing output directory...
if exist %OUTPUT_DIR% (
    rmdir /s /q %OUTPUT_DIR%
)
mkdir %OUTPUT_DIR%

if "%BUILD_TYPE%"=="3" (
    :: App Bundle
    if exist build\app\outputs\bundle\release\app-release.aab (
        copy /y build\app\outputs\bundle\release\app-release.aab %OUTPUT_DIR%\ >nul
        echo [OK] Copied app-release.aab
    ) else (
        echo [WARN] app-release.aab not found
    )
) else (
    :: APK
    if exist build\app\outputs\flutter-apk\app-%BUILD_MODE%.apk (
        copy /y build\app\outputs\flutter-apk\app-%BUILD_MODE%.apk %OUTPUT_DIR%\ >nul
        echo [OK] Copied app-%BUILD_MODE%.apk
    ) else (
        echo [WARN] app-%BUILD_MODE%.apk not found
    )
    :: Also copy multi-arch APKs if exist
    if exist build\app\outputs\flutter-apk\app-%BUILD_MODE%-x86_64.apk (
        copy /y build\app\outputs\flutter-apk\app-%BUILD_MODE%-*.apk %OUTPUT_DIR%\ >nul
        echo [OK] Copied split APKs
    )
)

:: Write version file
echo %VERSION% > %OUTPUT_DIR%\version.txt

:: Show file sizes
echo.
echo =============================================
echo  Build Complete!
echo  Version: %VERSION%
echo  Output: %OUTPUT_DIR%\
echo ---------------------------------------------
for %%f in (%OUTPUT_DIR%\*) do (
    call :FormatSize %%~zf "%%~nxf"
)
echo =============================================

endlocal
pause
exit /b 0

:FormatSize
set SIZE=%~1
set NAME=%~2
if %SIZE% geq 1073741824 (
    set /a "SIZE_MB=%SIZE% / 1073741824"
    echo  %NAME%: %SIZE_MB%.!SIZE_MB:~0! GB
) else if %SIZE% geq 1048576 (
    set /a "SIZE_MB=%SIZE% / 1048576"
    set /a "SIZE_REM=%SIZE% %% 1048576 * 100 / 1048576"
    echo  %NAME%: %SIZE_MB%.!SIZE_REM! MB
) else if %SIZE% geq 1024 (
    set /a "SIZE_KB=%SIZE% / 1024"
    echo  %NAME%: %SIZE_KB% KB
) else (
    echo  %NAME%: %SIZE% B
)
exit /b
