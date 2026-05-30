@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo ============================================
echo  Smart Assistant - Build and Run on Emulator
echo ============================================
echo.

REM ---- step 1: find emulator ----
set AVD_DIR=%USERPROFILE%\.android\avd

if not exist "%AVD_DIR%" (
    echo [ERROR] No AVD directory found.
    echo Please create an emulator in Android Studio first.
    pause
    exit /b 1
)

set COUNT=0
for /f "tokens=*" %%a in ('dir /b "%AVD_DIR%\*.ini" 2^>nul') do (
    set /a COUNT+=1
    set EMU_!COUNT!=%%~na
    echo   [!COUNT!] %%~na
)

if !COUNT! equ 0 (
    echo [ERROR] No Android emulator found.
    echo Create one in Android Studio: Device Manager ^> Create Device
    pause
    exit /b 1
)

if !COUNT! equ 1 (
    set EMU_ID=!EMU_1!
    echo.
    echo [*] Only one emulator, using: !EMU_ID!
) else (
    echo.
    set /p SEL="Select emulator (1-!COUNT!, Enter to cancel): "
    if "%SEL%"=="" (
        echo Cancelled.
        pause
        exit /b 0
    )
    if !SEL! lss 1 goto bad_sel
    if !SEL! gtr !COUNT! goto bad_sel
    set EMU_ID=!EMU_%SEL%!
)

echo.
echo ============================================
echo [1/4] Launching emulator: !EMU_ID! (DNS: 8.8.8.8)
echo ============================================
echo.

REM Locate emulator.exe: try ANDROID_SDK_ROOT, then ANDROID_HOME, fallback to E:\android-sdk
set EMULATOR_EXE=
if defined ANDROID_SDK_ROOT set EMULATOR_EXE=%ANDROID_SDK_ROOT%\emulator\emulator.exe
if not defined EMULATOR_EXE if defined ANDROID_HOME set EMULATOR_EXE=%ANDROID_HOME%\emulator\emulator.exe
if not defined EMULATOR_EXE set EMULATOR_EXE=E:\android-sdk\emulator\emulator.exe
if not exist "%EMULATOR_EXE%" (
    echo [WARN] emulator.exe not found, falling back to flutter emulators --launch
    start "" flutter emulators --launch !EMU_ID!
) else (
    start "" "%EMULATOR_EXE%" -avd !EMU_ID! -dns-server 8.8.8.8,114.114.114.114
)

REM ---- step 2: wait for emulator to boot ----
echo.
echo ============================================
echo [2/4] Waiting for emulator to boot...
echo ============================================
echo.

echo Waiting for device...
adb wait-for-device >nul 2>nul
if !errorlevel! neq 0 (
    echo [WARN] adb wait-for-device failed, retrying...
    timeout /t 5 /nobreak >nul
)

set BOOT_WAIT=0

:wait_boot
for /f "tokens=2 delims=:" %%a in ('adb shell getprop sys.boot_completed 2^>nul') do set BOOT=%%a
set BOOT=!BOOT: =!
if "!BOOT!"=="1" goto boot_ok

set /a BOOT_WAIT+=3
if !BOOT_WAIT! gtr 120 (
    echo [WARN] Emulator boot timeout (120s). Trying to continue anyway...
    goto boot_skip
)
echo Waiting for emulator to boot... (!BOOT_WAIT!s)
timeout /t 3 /nobreak >nul
goto wait_boot

:boot_ok
echo [*] Emulator booted successfully.
goto after_boot

:boot_skip
echo [*] Skipping boot check, proceeding.

:after_boot
echo.

REM ---- step 3: build debug APK ----
echo.
echo ============================================
echo [3/4] Building debug APK...
echo ============================================
echo.

flutter build apk --debug
if !errorlevel! neq 0 (
    echo [ERROR] Build failed. Check errors above.
    pause
    exit /b 1
)

echo [*] Build succeeded.

REM ---- step 4: install and launch ----
echo.
echo ============================================
echo [4/4] Installing and launching on emulator...
echo ============================================
echo.

flutter run --debug
goto done

:bad_sel
echo [ERROR] Invalid selection.
pause
exit /b 1

:done
echo.
echo ============================================
echo  Done.
echo ============================================
echo.

pause
