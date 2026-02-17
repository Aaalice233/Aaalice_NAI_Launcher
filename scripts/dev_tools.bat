@echo off
chcp 65001 >nul
echo ==========================================
echo     NAI Launcher 开发工具
echo ==========================================
echo.

REM 使用 E 盘的 Flutter
set FLUTTER=E:\flutter\bin\flutter.bat
set DART=E:\flutter\bin\dart.bat

REM 检查 Flutter 是否存在
if not exist %FLUTTER% (
    echo [错误] 未找到 Flutter: %FLUTTER%
    echo 请修改此脚本设置正确的 Flutter 路径
    pause
    exit /b 1
)

REM 显示菜单
:menu
echo 请选择要执行的操作:
echo.
echo   [1] 运行代码分析 (flutter analyze)
echo   [2] 生成代码 (build_runner)
echo   [3] 分析 + 生成 (完整检查)
echo   [4] 生成国际化代码
echo   [5] 修复代码风格 (dart fix)
echo   [6] 运行测试
echo   [0] 退出
echo.
set /p choice="输入选项 (0-6): "

if "%choice%"=="1" goto analyze
if "%choice%"=="2" goto build_runner
if "%choice%"=="3" goto full_check
if "%choice%"=="4" goto gen_l10n
if "%choice%"=="5" goto dart_fix
if "%choice%"=="6" goto test
if "%choice%"=="0" goto exit

echo [错误] 无效选项
goto menu

:analyze
echo.
echo ==========================================
echo 正在运行 Flutter 分析...
echo ==========================================
call %FLUTTER% analyze
if %errorlevel% neq 0 (
    echo.
    echo [警告] 分析发现问题
) else (
    echo.
    echo [成功] 分析通过，无错误
)
pause
goto menu

:build_runner
echo.
echo ==========================================
echo 正在运行 Build Runner...
echo ==========================================
call %DART% run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo.
    echo [错误] 代码生成失败
) else (
    echo.
    echo [成功] 代码生成完成
)
pause
goto menu

:full_check
echo.
echo ==========================================
echo 步骤 1/3: 运行代码分析...
echo ==========================================
call %FLUTTER% analyze
if %errorlevel% neq 0 (
    echo.
    echo [警告] 分析发现问题，继续生成代码...
)

echo.
echo ==========================================
echo 步骤 2/3: 生成国际化代码...
echo ==========================================
call %FLUTTER% gen-l10n
if %errorlevel% neq 0 (
    echo.
    echo [错误] 国际化代码生成失败
    pause
    goto menu
)

echo.
echo ==========================================
echo 步骤 3/3: 运行 Build Runner...
echo ==========================================
call %DART% run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo.
    echo [错误] 代码生成失败
    pause
    goto menu
)

echo.
echo ==========================================
echo [成功] 完整检查完成！
echo ==========================================
pause
goto menu

:gen_l10n
echo.
echo ==========================================
echo 正在生成国际化代码...
echo ==========================================
call %FLUTTER% gen-l10n
if %errorlevel% neq 0 (
    echo.
    echo [错误] 国际化代码生成失败
) else (
    echo.
    echo [成功] 国际化代码生成完成
)
pause
goto menu

:dart_fix
echo.
echo ==========================================
echo 正在修复代码风格...
echo ==========================================
call %DART% fix --apply
echo.
echo [完成] 代码风格修复完成
pause
goto menu

:test
echo.
echo ==========================================
echo 正在运行测试...
echo ==========================================
call %FLUTTER% test
echo.
echo [完成] 测试运行完成
pause
goto menu

:exit
echo.
echo 再见！
exit /b 0
