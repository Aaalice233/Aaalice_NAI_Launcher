@echo off
chcp 65001 >nul

echo ==========================================
echo     NAI Launcher - 完整代码检查和修复
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

echo [1/5] 安装依赖 (flutter pub get)...
echo ------------------------------------------
call %FLUTTER% pub get
if %errorlevel% neq 0 (
    echo.
    echo [错误] 依赖安装失败
    pause
    exit /b 1
)
echo [成功] 依赖安装完成
echo.

echo [2/5] 生成国际化代码 (flutter gen-l10n)...
echo ------------------------------------------
call %FLUTTER% gen-l10n
if %errorlevel% neq 0 (
    echo.
    echo [错误] 国际化代码生成失败
    pause
    exit /b 1
)
echo [成功] 国际化代码生成完成
echo.

echo [3/5] 运行 Build Runner 生成代码...
echo ------------------------------------------
call %DART% run build_runner build --delete-conflicting-outputs
if %errorlevel% neq 0 (
    echo.
    echo [错误] 代码生成失败
    pause
    exit /b 1
)
echo [成功] 代码生成完成
echo.

echo [4/5] 运行代码分析 (flutter analyze)...
echo ------------------------------------------
call %FLUTTER% analyze
if %errorlevel% neq 0 (
    echo.
    echo [警告] 分析发现问题，继续执行修复...
) else (
    echo.
    echo [成功] 分析通过，无错误
)
echo.

echo [5/5] 自动修复代码问题 (dart fix --apply)...
echo ------------------------------------------
call %DART% fix --apply
echo.
echo [完成] 自动修复已应用
echo.

echo ==========================================
echo [全部完成] 代码检查和修复流程已结束！
echo ==========================================
pause
