@echo off
chcp 65001 >nul

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

echo [1/3] Running flutter analyze...
call "%FLUTTER_CMD%" analyze
if %errorlevel% neq 0 (
    echo [WARNING] Analysis found issues
) else (
    echo [OK] Analysis passed
)

echo.
echo [2/3] Generating localization...
call "%FLUTTER_CMD%" gen-l10n
echo [OK] Localization generated

echo.
echo [3/3] Running build_runner...
call "%DART_CMD%" run build_runner build --delete-conflicting-outputs
echo [OK] Code generation complete

echo.
echo ==========================================
echo Quick check finished!
echo ==========================================
pause
