# 内置 CSV 文件下载指南

## 概述

所有翻译和共现数据 CSV 文件现在都改为**内置**，不再从远程下载。用户首次安装即可使用，无需等待网络下载。

## 文件目录结构

```
assets/
└── translations/
    ├── danbooru_zh.csv              # 本地高质量中文翻译
    ├── wai_characters.csv           # 角色翻译（已存在）
    ├── hf_danbooru_tags.csv         # HuggingFace 标签数据
    ├── hf_danbooru_cooccurrence.csv # HuggingFace 共现数据
    ├── github_sanlvzhetang.csv      # GitHub Sanlvzhetang 翻译
    └── github_chening233.csv        # GitHub CheNing233 Wiki 翻译
```

## 下载地址

### 1. danbooru_zh.csv

**来源**: 基于本地 `danbooru.csv` 整理优化

**处理方式**:
```bash
# 直接使用现有的 assets/translations/danbooru.csv
# 复制并重命名为 danbooru_zh.csv
cp assets/translations/danbooru.csv assets/translations/danbooru_zh.csv
```

**格式**: `tag,zh_translation`
**示例**:
```csv
1girl,女孩
simple_background,朴素的背景
```

---

### 2. hf_danbooru_tags.csv

**下载地址**: https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main/danbooru_tags.csv

**格式**: `tag,category,count,alias1,alias2,alias3...`
**标题行**: 有
**示例**:
```csv
tag,category,count,alias
1girl,0,4974288,"女の子,女性,少女,girl,おんなのこ,女子,소녀,女孩,姑娘,女,ガール"
solo,0,4005860,"ソロ,solo,ひとり"
```

**下载命令**:
```bash
curl -L -o assets/translations/hf_danbooru_tags.csv \
  "https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main/danbooru_tags.csv"
```

---

### 3. hf_danbooru_cooccurrence.csv

**下载地址**: https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main/danbooru_tags_cooccurrence.csv

**格式**: `tag1,tag2,count`
**标题行**: 有
**示例**:
```csv
tag1,tag2,count
1girl,solo,1234567
1girl,long_hair,987654
```

**下载命令**:
```bash
curl -L -o assets/translations/hf_danbooru_cooccurrence.csv \
  "https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main/danbooru_tags_cooccurrence.csv"
```

---

### 4. github_sanlvzhetang.csv

**下载地址**: https://raw.githubusercontent.com/SANLVZHETANG/danbooru-tag-list-zh/main/danbooru-12-10-24-underscore.csv

**格式**: `tag,zh_translation`
**标题行**: 有
**示例**:
```csv
tag,translation
1girl,女孩
solo,单人
```

**下载命令**:
```bash
curl -L -o assets/translations/github_sanlvzhetang.csv \
  "https://raw.githubusercontent.com/SANLVZHETANG/danbooru-tag-list-zh/main/danbooru-12-10-24-underscore.csv"
```

---

### 5. github_chening233.csv

**下载地址**: https://raw.githubusercontent.com/CheNing233/datasets_danbooru_tag_wiki/main/danbooru_tag_wiki.csv

**格式**: `danbooru_text,danbooru_url,tag,danbooru_translation`
**标题行**: 有
**示例**:
```csv
danbooru_text,danbooru_url,tag,danbooru_translation
1girl,https://danbooru.donmai.us/wiki_pages/1girl,1girl,"女孩,女の子,少女"
```

**下载命令**:
```bash
curl -L -o assets/translations/github_chening233.csv \
  "https://raw.githubusercontent.com/CheNing233/datasets_danbooru_tag_wiki/main/danbooru_tag_wiki.csv"
```

---

### 6. wai_characters.csv

**说明**: 已存在于项目中

**格式**: `zh_name,en_tag`
**示例**:
```csv
御坂美琴,misaka_mikoto
初音未来,hatsune_miku
```

---

## 一键下载脚本

创建 `download_csv.sh`:

```bash
#!/bin/bash

set -e

cd "$(dirname "$0")/assets/translations"

echo "Downloading CSV files..."

# HuggingFace Danbooru Tags
echo "Downloading hf_danbooru_tags.csv..."
curl -L -o "hf_danbooru_tags.csv" \
  "https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main/danbooru_tags.csv"

# HuggingFace Cooccurrence
echo "Downloading hf_danbooru_cooccurrence.csv..."
curl -L -o "hf_danbooru_cooccurrence.csv" \
  "https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main/danbooru_tags_cooccurrence.csv"

# GitHub Sanlvzhetang
echo "Downloading github_sanlvzhetang.csv..."
curl -L -o "github_sanlvzhetang.csv" \
  "https://raw.githubusercontent.com/SANLVZHETANG/danbooru-tag-list-zh/main/danbooru-12-10-24-underscore.csv"

# GitHub CheNing233
echo "Downloading github_chening233.csv..."
curl -L -o "github_chening233.csv" \
  "https://raw.githubusercontent.com/CheNing233/datasets_danbooru_tag_wiki/main/danbooru_tag_wiki.csv"

# Copy local danbooru.csv to danbooru_zh.csv
echo "Copying danbooru_zh.csv..."
cp "danbooru.csv" "danbooru_zh.csv" 2>/dev/null || echo "Warning: danbooru.csv not found"

echo "Done!"
echo ""
echo "File sizes:"
ls -lh *.csv
```

Windows PowerShell 版本 `download_csv.ps1`:

```powershell
$ErrorActionPreference = "Stop"

$transDir = "$PSScriptRoot/assets/translations"
Set-Location $transDir

Write-Host "Downloading CSV files..."

# HuggingFace Danbooru Tags
Write-Host "Downloading hf_danbooru_tags.csv..."
Invoke-WebRequest -Uri "https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main/danbooru_tags.csv" -OutFile "hf_danbooru_tags.csv"

# HuggingFace Cooccurrence
Write-Host "Downloading hf_danbooru_cooccurrence.csv..."
Invoke-WebRequest -Uri "https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv/resolve/main/danbooru_tags_cooccurrence.csv" -OutFile "hf_danbooru_cooccurrence.csv"

# GitHub Sanlvzhetang
Write-Host "Downloading github_sanlvzhetang.csv..."
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SANLVZHETANG/danbooru-tag-list-zh/main/danbooru-12-10-24-underscore.csv" -OutFile "github_sanlvzhetang.csv"

# GitHub CheNing233
Write-Host "Downloading github_chening233.csv..."
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/CheNing233/datasets_danbooru_tag_wiki/main/danbooru_tag_wiki.csv" -OutFile "github_chening233.csv"

# Copy local danbooru.csv to danbooru_zh.csv
Write-Host "Copying danbooru_zh.csv..."
Copy-Item "danbooru.csv" "danbooru_zh.csv" -ErrorAction SilentlyContinue

Write-Host "Done!"
Write-Host ""
Write-Host "File sizes:"
Get-ChildItem *.csv | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB,2)}}
```

---

## 更新 pubspec.yaml

确保 assets 配置包含所有 CSV 文件：

```yaml
flutter:
  assets:
    - assets/translations/danbooru_zh.csv
    - assets/translations/wai_characters.csv
    - assets/translations/hf_danbooru_tags.csv
    - assets/translations/hf_danbooru_cooccurrence.csv
    - assets/translations/github_sanlvzhetang.csv
    - assets/translations/github_chening233.csv
```

## 关于 Danbooru API 标签补全

**只有这个功能保持远程 API 调用**：

- 用途：获取实时热门标签、新标签
- 地址：https://danbooru.donmai.us/tags.json
- 实现：`DanbooruApiService.suggestTags()`

**标签补全数据量大，无法内置**：
- Danbooru 有数十万标签
- 实时变化
- 分批获取（每页 1000 条）

---

## 数据优先级

合并时按优先级排序：

1. **100** - danbooru_zh.csv (最高优先级)
2. **100** - wai_characters.csv
3. **60** - github_sanlvzhetang.csv
4. **50** - hf_danbooru_tags.csv
5. **40** - github_chening233.csv

高优先级的翻译会覆盖低优先级的同名标签翻译。
