# Danbooru 补充词库方案

## 概述
NAI 固定词库（1801个）为主，可选从 Danbooru 补充额外标签。

## 架构

```
┌─────────────────────────────────────────┐
│           TagLibrary (最终)              │
├─────────────────────────────────────────┤
│  NAI 固定标签 (nai_official_tags.json)   │
│  + Danbooru 补充标签 (可选，用户开关)     │
└─────────────────────────────────────────┘
```

## 实施步骤

### Step 1: 添加用户设置开关
- 文件: `lib/data/models/prompt/sync_config.dart`
- 新增字段: `enableDanbooruSupplement: bool`
- 默认值: `false`

### Step 2: 修改 TagLibrary 结构
- 文件: `lib/data/models/prompt/tag_library.dart`
- 新增字段: `supplementSource: TagLibrarySource?`
- 区分 NAI 固定标签和 Danbooru 补充标签

### Step 3: 修改 DanbooruTagLibraryService
- 文件: `lib/data/datasources/remote/danbooru_tag_library_service.dart`
- 新增方法: `fetchSupplementTags()`
- 补充逻辑:
  - 基于 NAI 现有标签生成 Danbooru 查询模式
  - 只获取 NAI 中没有的标签
  - 合并时 NAI 标签优先

### Step 4: 修改 TagLibraryService
- 文件: `lib/data/services/tag_library_service.dart`
- 修改 `syncLibrary()`:
  1. 加载 NAI 固定标签（必须）
  2. 检查用户开关
  3. 如果开启，从 Danbooru 获取补充标签
  4. 合并词库（NAI 优先）
- 新增方法: `getEffectiveLibrary()` - 获取最终可用词库

### Step 5: 修改设置界面
- 文件: `lib/presentation/screens/settings/settings_screen.dart`
- 添加开关: "从 Danbooru 补充词库"
- 添加说明文本

### Step 6: 补充匹配词生成逻辑
- 基于 NAI 标签生成 Danbooru 查询:
  - `*_hair` → 发色/发型扩展
  - `*_eyes` → 瞳色扩展
  - `*_background` → 背景扩展
  - 其他类别使用 NAI 标签作为种子词

## 数据流

```
用户点击同步
    ↓
加载 NAI 固定标签 (nai_official_tags.json)
    ↓
检查 enableDanbooruSupplement 开关
    ↓ (开启)
基于 NAI 标签生成 Danbooru 查询模式
    ↓
从 Danbooru 获取补充标签
    ↓
过滤掉 NAI 已有的标签
    ↓
合并生成最终词库
    ↓
保存到本地
```

## 文件修改清单

| 文件 | 修改类型 | 内容 |
|------|----------|------|
| sync_config.dart | 修改 | 添加 enableDanbooruSupplement 字段 |
| tag_library.dart | 修改 | 添加 supplementSource 字段 |
| danbooru_tag_library_service.dart | 修改 | 添加补充标签获取逻辑 |
| tag_library_service.dart | 修改 | 添加合并逻辑 |
| settings_screen.dart | 修改 | 添加开关 UI |
| app_zh.arb / app_en.arb | 修改 | 添加国际化文本 |
