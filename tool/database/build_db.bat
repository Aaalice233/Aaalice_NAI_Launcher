@echo off
set "ROOT=%~dp0..\.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
cd /d "%ROOT%"
if not defined DART_CMD (
    for /f "delims=" %%D in ('where dart 2^>nul') do if not defined DART_CMD set "DART_CMD=%%D"
)
if not defined DART_CMD (
    echo [ERROR] Dart command not found. Add Dart to PATH or set DART_CMD.
    pause
    exit /b 1
)
call "%DART_CMD%" run tool\database\build_databases.dart
pause
