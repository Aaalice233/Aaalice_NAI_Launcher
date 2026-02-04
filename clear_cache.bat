@echo off
chcp 65001 >nul
echo ========================================
echo   清空 NAI Launcher 数据源缓存
echo ========================================
echo.

set "CACHE_DIR=%APPDATA%\nai_launcher"

if not exist "%CACHE_DIR%" (
    echo 缓存目录不存在: %CACHE_DIR%
    pause
    exit /b 1
)

echo 缓存目录: %CACHE_DIR%
echo.

:: 删除 SQLite 数据库
echo --- 删除 SQLite 数据库 ---
if exist "%CACHE_DIR%\databases\cooccurrence.db" (
    del /f /q "%CACHE_DIR%\databases\cooccurrence.db" 2>nul && echo ✓ cooccurrence.db || echo ✗ cooccurrence.db (删除失败)
) else (
    echo ○ cooccurrence.db (不存在)
)

if exist "%CACHE_DIR%\databases\translation.db" (
    del /f /q "%CACHE_DIR%\databases\translation.db" 2>nul && echo ✓ translation.db || echo ✗ translation.db (删除失败)
) else (
    echo ○ translation.db (不存在)
)

if exist "%CACHE_DIR%\databases\danbooru_tags.db" (
    del /f /q "%CACHE_DIR%\databases\danbooru_tags.db" 2>nul && echo ✓ danbooru_tags.db || echo ✗ danbooru_tags.db (删除失败)
) else (
    echo ○ danbooru_tags.db (不存在)
)

:: 删除元数据文件
echo.
echo --- 删除元数据文件 ---
set "META_FILES=cooccurrence_meta.json danbooru_tags_meta.json danbooru_artists_meta.json translation_meta.json tags_meta.json"

for %%f in (%META_FILES%) do (
    if exist "%CACHE_DIR%\%%f" (
        del /f /q "%CACHE_DIR%\%%f" 2>nul && echo ✓ %%f || echo ✗ %%f (删除失败)
    ) else (
        echo ○ %%f (不存在)
    )
)

:: 删除 CSV 缓存
echo.
echo --- 删除 CSV 缓存 ---
set "CSV_FILES=danbooru_artists.csv tags.csv translation.csv translation_zh.csv"

for %%f in (%CSV_FILES%) do (
    if exist "%CACHE_DIR%\%%f" (
        del /f /q "%CACHE_DIR%\%%f" 2>nul && echo ✓ %%f || echo ✗ %%f (删除失败)
    ) else (
        echo ○ %%f (不存在)
    )
)

:: 删除旧版二进制缓存
echo.
echo --- 删除旧版缓存 ---
set "OLD_FILES=cooccurrence_data.bin cooccurrence_cache.json"

for %%f in (%OLD_FILES%) do (
    if exist "%CACHE_DIR%\%%f" (
        del /f /q "%CACHE_DIR%\%%f" 2>nul && echo ✓ %%f || echo ✗ %%f (删除失败)
    ) else (
        echo ○ %%f (不存在)
    )
)

echo.
echo ========================================
echo   清理完成
echo ========================================
echo.
echo 请确保应用已关闭，然后重新启动。
echo 应用将在下次启动时重新下载数据。
echo.
pause
