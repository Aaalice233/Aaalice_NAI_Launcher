# 多数据源翻译架构设计（内置版）

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                    UnifiedTranslationService                    │
│                     (统一翻译服务 - 纯内置)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐ │
│  │ danbooru_zh.csv │    │ hf_danbooru_    │    │ github_*.csv │ │
│  │   (priority 100)│    │ tags.csv        │    │  (priority   │ │
│  │                 │    │   (priority 50) │    │   40-60)     │ │
│  └────────┬────────┘    └────────┬────────┘    └──────┬───────┘ │
│           │                      │                     │         │
│           └──────────────────────┼─────────────────────┘         │
│                                  ▼                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Merged Translation Map                       │  │
│  │     (高优先级数据源覆盖低优先级数据源的翻译)               │  │
│  │     simple_background: "朴素的背景"  ← 来自 danbooru_zh   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    应用场景（离线可用）                          │
│  1. 自动补全翻译 (DanbooruSuggestionProvider) ✓                  │
│  2. 标签卡片显示 (TagChip) ✓                                     │
│  3. 搜索提示 (SearchSuggestions) ✓                               │
│  4. 共现标签推荐 ✓                                               │
└─────────────────────────────────────────────────────────────────┘
```

## 核心特点

### 1. 纯内置，无需网络

所有 CSV 文件都打包在应用内：
- 首次安装即可使用
- 无需等待下载
- 离线完全可用

### 2. 多数据源合并

| 数据源 | 文件 | 优先级 | 说明 |
|--------|------|--------|------|
| 本地高质量 | `danbooru_zh.csv` | 100 | 精简高质量中文翻译 |
| HuggingFace | `hf_danbooru_tags.csv` | 50 | 多语言 alias |
| GitHub sanlvzhetang | `github_sanlvzhetang.csv` | 60 | 社区中文翻译 |
| GitHub CheNing233 | `github_chening233.csv` | 40 | Wiki 翻译 |
| 角色翻译 | `wai_characters.csv` | 100 | 角色名称 |

### 3. 优先级覆盖机制

```
优先级 100 > 60 > 50 > 40

例：simple_background
- hf_danbooru_tags.csv: "" (空)
- danbooru_zh.csv: "朴素的背景" ✓ 使用这个
```

## 文件结构

```
assets/translations/
├── danbooru_zh.csv              # 内置，高质量中文翻译
├── wai_characters.csv           # 内置，角色翻译
├── hf_danbooru_tags.csv         # 内置，HuggingFace 标签数据
├── hf_danbooru_cooccurrence.csv # 内置，共现数据
├── github_sanlvzhetang.csv      # 内置，社区翻译
└── github_chening233.csv        # 内置，Wiki 翻译
```

## 使用方式

### 获取翻译

```dart
// 获取单个翻译
final translation = ref.watch(tagTranslationProvider('simple_background'));
// 返回: "朴素的背景"

// 批量获取
final translations = ref.watch(tagTranslationsProvider(['1girl', 'solo']));
// 返回: {'1girl': '女孩', 'solo': '单人'}
```

### 搜索翻译

```dart
// 搜索包含"背景"的标签
final results = ref.watch(searchTranslationsProvider(query: '背景'));
// 返回: [simple_background, white_background, ...]
```

## 共现标签数据

共现数据也改为内置：

```dart
// 使用内置共现 CSV
final cooccurrenceSource = PredefinedCooccurrenceSources.hfCooccurrence;
```

## 唯一远程 API

**Danbooru 标签补全 API**：

```
地址: https://danbooru.donmai.us/tags.json
用途: 获取实时热门标签、搜索提示
原因: 数据量大（数十万标签）、实时变化
```

实现：`DanbooruApiService.suggestTags()`

---

## 文件清单

查看 `docs/built_in_csv_guide.md` 获取：
- 各 CSV 文件下载地址
- 格式说明
- 一键下载脚本
- pubspec.yaml 配置
