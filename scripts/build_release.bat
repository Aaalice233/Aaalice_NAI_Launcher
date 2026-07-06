@echo off
setlocal

set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"

pwsh -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\package_windows_release.ps1"
if %ERRORLEVEL% neq 0 (
  echo.
  echo [ERROR] Release build failed.
  pause
  exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Release packages were created in dist.
pause
