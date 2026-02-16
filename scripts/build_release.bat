@echo off
setlocal enabledelayedexpansion

cd /d E:\Aaalice_NAI_Launcher

echo ========================================
echo   NAI Launcher Release Build
echo ========================================
echo.

:: 配置
set "EXE_PATH=E:\Aaalice_NAI_Launcher\build\windows\x64\runner\Release\nai_launcher.exe"
set "PFX_PATH=E:\Aaalice_NAI_Launcher\scripts\nai_launcher.pfx"
set "PFX_PASSWORD=NaiLauncher2024"
set "TIMESTAMP_URL=http://timestamp.digicert.com"

echo [0/4] Building prebuilt database...
echo.

call E:\flutter\bin\dart.bat scripts\build_prebuilt_database.dart
if %ERRORLEVEL% neq 0 (
    echo.
    echo [WARNING] Prebuilt database generation failed, continuing with build...
)

echo.
echo [1/4] Building release version...
echo.
call E:\flutter\bin\flutter.bat build windows --release

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
