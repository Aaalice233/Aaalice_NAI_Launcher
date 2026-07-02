@echo off
chcp 65001 >nul

echo ==========================================
echo     NAI Launcher - 完整代码检查和修复
echo ==========================================
echo.

if not defined FLUTTER_CMD (
    for /f "delims=" %%F in ('where flutter 2^>nul') do if not defined FLUTTER_CMD set "FLUTTER_CMD=%%F"
)
if not defined DART_CMD (
    for /f "delims=" %%D in ('where dart 2^>nul') do if not defined DART_CMD set "DART_CMD=%%D"
)
if not defined FLUTTER_CMD (
    echo [错误] 未找到 Flutter。请将 Flutter 加入 PATH，或设置 FLUTTER_CMD。
    pause
    exit /b 1
)
if not defined DART_CMD (
    echo [错误] 未找到 Dart。请将 Dart 加入 PATH，或设置 DART_CMD。
    pause
    exit /b 1
)

echo [1/5] 安装依赖 (flutter pub get)...
echo ------------------------------------------
call "%FLUTTER_CMD%" pub get
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
call "%FLUTTER_CMD%" gen-l10n
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
call "%DART_CMD%" run build_runner build --delete-conflicting-outputs
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
call "%FLUTTER_CMD%" analyze
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
call "%DART_CMD%" fix --apply
echo.
echo [完成] 自动修复已应用
echo.

echo ==========================================
echo [全部完成] 代码检查和修复流程已结束！
echo ==========================================
pause
