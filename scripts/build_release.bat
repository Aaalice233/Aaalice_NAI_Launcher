@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
cd /d "%ROOT%"

echo ========================================
echo   NAI Launcher Release Build
echo ========================================
echo.

:: 配置
set "EXE_PATH=%ROOT%\build\windows\x64\runner\Release\nai_launcher.exe"
set "PFX_PATH=%ROOT%\scripts\nai_launcher.pfx"
set "PFX_PASSWORD=NaiLauncher2024"
set "TIMESTAMP_URL=http://timestamp.digicert.com"

if not defined FLUTTER_CMD (
    for /f "delims=" %%F in ('where flutter 2^>nul') do if not defined FLUTTER_CMD set "FLUTTER_CMD=%%F"
)
if not defined DART_CMD (
    for /f "delims=" %%D in ('where dart 2^>nul') do if not defined DART_CMD set "DART_CMD=%%D"
)
if not defined FLUTTER_CMD (
    echo [ERROR] Flutter command not found. Add Flutter to PATH or set FLUTTER_CMD.
    pause
    exit /b 1
)
if not defined DART_CMD (
    echo [ERROR] Dart command not found. Add Dart to PATH or set DART_CMD.
    pause
    exit /b 1
)

echo [0/4] Building prebuilt database...
echo.

call "%DART_CMD%" scripts\build_prebuilt_database.dart
if %ERRORLEVEL% neq 0 (
    echo.
    echo [WARNING] Prebuilt database generation failed, continuing with build...
)

echo.
echo [1/4] Building release version...
echo.
call "%FLUTTER_CMD%" build windows --release

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

echo.
echo [2/4] Checking for signing certificate...

if not exist "%PFX_PATH%" (
    echo.
    echo [WARNING] Signing certificate not found: %PFX_PATH%
    echo [INFO] To enable code signing, run:
    echo        PowerShell -ExecutionPolicy Bypass -File scripts\create_signing_cert.ps1
    echo.
    echo [INFO] Skipping signing step...
    goto :done
)

echo [3/4] Signing executable...
echo.

:: 查找 signtool.exe
set "SIGNTOOL="
for %%d in (
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64"
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64"
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.19041.0\x64"
    "C:\Program Files (x86)\Windows Kits\10\bin\x64"
) do (
    if exist "%%~d\signtool.exe" (
        set "SIGNTOOL=%%~d\signtool.exe"
        goto :found_signtool
    )
)

echo [WARNING] signtool.exe not found. Please install Windows SDK.
echo [INFO] Download from: https://developer.microsoft.com/windows/downloads/windows-sdk/
echo [INFO] Skipping signing step...
goto :done

:found_signtool
echo Using signtool: %SIGNTOOL%
echo.

"%SIGNTOOL%" sign /f "%PFX_PATH%" /p "%PFX_PASSWORD%" /fd SHA256 /tr "%TIMESTAMP_URL%" /td SHA256 /d "NAI Launcher" "%EXE_PATH%"

if %ERRORLEVEL% neq 0 (
    echo.
    echo [WARNING] Signing failed, but build is complete.
) else (
    echo.
    echo [SUCCESS] Executable signed successfully!
)

:done
echo.
echo ========================================
echo   Build Complete!
echo ========================================
echo.
echo Release exe at:
echo %EXE_PATH%
echo.
pause
