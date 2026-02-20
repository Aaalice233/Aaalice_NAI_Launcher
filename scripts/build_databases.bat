@echo off
chcp 65001
cls

echo ==========================================
echo    NAI Launcher Database Build Tool
echo ==========================================
echo.

if not exist "assets\translations\hf_danbooru_tags.csv" (
    echo [ERROR] Translation CSV not found: assets\translations\hf_danbooru_tags.csv
    pause
    exit /b 1
)

if not exist "assets\translations\hf_danbooru_cooccurrence.csv" (
    echo [ERROR] Cooccurrence CSV not found: assets\translations\hf_danbooru_cooccurrence.csv
    pause
    exit /b 1
)

echo [INFO] Starting database build...
echo [INFO] This may take 1-2 minutes depending on your system.
echo.

E:\flutter\bin\dart.bat tools\build_databases.dart

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Build failed with error code %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Database build completed!
echo [INFO] Output location: assets\databases\
echo.
pause
