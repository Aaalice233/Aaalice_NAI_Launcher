@echo off
chcp 65001 >nul

REM 使用 E 盘的 Flutter
set FLUTTER=E:\flutter\bin\flutter.bat
set DART=E:\flutter\bin\dart.bat

echo [1/3] Running flutter analyze...
call %FLUTTER% analyze
if %errorlevel% neq 0 (
    echo [WARNING] Analysis found issues
) else (
    echo [OK] Analysis passed
)

echo.
echo [2/3] Generating localization...
call %FLUTTER% gen-l10n
echo [OK] Localization generated

echo.
echo [3/3] Running build_runner...
call %DART% run build_runner build --delete-conflicting-outputs
echo [OK] Code generation complete

echo.
echo ==========================================
echo Quick check finished!
echo ==========================================
pause
