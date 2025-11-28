@echo off
cd /d E:\Aaalice_NAI_Launcher
echo Building release version...
call E:\flutter\bin\flutter.bat build windows --release
echo.
echo Build complete! Release exe at:
echo E:\Aaalice_NAI_Launcher\build\windows\x64\runner\Release\nai_launcher.exe
pause
