# 修复 CSV 数据加载问题实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复共现数据和翻译数据没有正确从本地 assets CSV 文件加载的问题

**Architecture:**
1. 修改 `CooccurrenceService.initializeLazy()` 方法，在数据库为空时优先从本地 assets 加载共现 CSV 数据
2. 确保 `TagTranslationService` 正确加载所有翻译 CSV 文件（`danbooru.csv` 已包含 `simple_background` 翻译）
3. 验证 CSV 解析逻辑正确处理所有格式

**Tech Stack:** Flutter/Dart, CSV 解析 (csv package), Isolate, Assets

---

## 问题分析

### 问题 1: 共现数据始终提示需要下载
- **原因**: `initializeLazy()` 只检查 SQLite 数据库是否有数据，没有尝试从 `assets/translations/hf_danbooru_cooccurrence.csv` 加载
- **位置**: `lib/core/services/cooccurrence_service.dart:1185-1217`

### 问题 2: simple_background 等标签找不到翻译
- **原因**: 检查 `danbooru.csv` 第 5394 行确实包含 `simple_background,朴素的背景`
- **可能原因**: 缓存未更新，或解析时未正确处理某些行
- **位置**: `lib/data/services/tag_translation_service.dart`

---

## Task 1: 修复共现数据本地 CSV 加载

**Files:**
- Modify: `lib/core/services/cooccurrence_service.dart:1185-1217`

**Step 1: 添加从 assets 加载共现 CSV 的方法**

在 `CooccurrenceService` 类中添加新方法：

```dart
/// 从本地 assets 加载共现数据
Future<bool> _loadFromAssets() async {
  try {
    onLoadProgress?.call(
      CooccurrenceLoadStage.reading,
      0.0,
      0.0,
      '从本地资源加载共现数据...',
    );

    final csvContent = await rootBundle.loadString(
      'assets/translations/hf_danbooru_cooccurrence.csv',
    );

    onLoadProgress?.call(
      CooccurrenceLoadStage.parsing,
      0.3,
      0.0,
      '解析共现数据...',
    );

    final result = await Isolate.run(
      () => _parseCooccurrenceDataWithProgressIsolate(
        csvContent,
        _DummySendPort(), // 不需要进度报告
      ),
    );

    onLoadProgress?.call(
      CooccurrenceLoadStage.merging,
      0.7,
      0.0,
      '合并数据...',
    );

    _data.replaceAllData(result);

    onLoadProgress?.call(
      CooccurrenceLoadStage.complete,
      1.0,
      1.0,
      '共现数据加载完成: ${result.length} 个标签',
    );

    AppLogger.i('Loaded cooccurrence data from assets: ${result.length} tags', 'Cooccurrence');
    return true;
  } catch (e, stack) {
    AppLogger.w('Failed to load cooccurrence from assets: $e', 'Cooccurrence');
    return false;
  }
}
```

**Step 2: 修改 initializeLazy 方法**

在 `initializeLazy()` 方法中，当数据库为空时，先尝试从 assets 加载：

```dart
Future<void> initializeLazy() async {
  if (_data.isLoaded) return;

  try {
    onProgress?.call(0.0, '初始化共现数据...');

    final unifiedDb = UnifiedTagDatabase();
    await unifiedDb.initialize();

    final counts = await unifiedDb.getRecordCounts();
    final hasData = counts.cooccurrences > 0;
    if (!hasData) {
      AppLogger.i('Cooccurrence database is empty, trying to load from assets...', 'Cooccurrence');

      // 先尝试从本地 assets 加载
      final loadedFromAssets = await _loadFromAssets();
      if (loadedFromAssets) {
        _unifiedDb = unifiedDb;
        _loadMode = CooccurrenceLoadMode.lazy;
        onProgress?.call(1.0, '共现数据加载完成');
        AppLogger.i('Cooccurrence data loaded from assets successfully', 'Cooccurrence');
        return;
      }

      // Assets 加载失败，标记为需要下载
      AppLogger.i('No local cooccurrence data available, will download after entering main screen', 'Cooccurrence');
      _unifiedDb = unifiedDb;
      _loadMode = CooccurrenceLoadMode.lazy;
      onProgress?.call(1.0, '需要下载共现数据');
      _lastUpdate = null;
      AppLogger.i('Cooccurrence lastUpdate reset to null, shouldRefresh will return true', 'Cooccurrence');
      return;
    }

    await setLoadMode(CooccurrenceLoadMode.lazy, unifiedDb: unifiedDb);

    _data.markLoaded();

    onProgress?.call(1.0, '共现数据初始化完成');
    AppLogger.i('Cooccurrence lazy initialization completed (hot data loading deferred)', 'Cooccurrence');
  } catch (e, stack) {
    AppLogger.e('Cooccurrence lazy initialization failed', e, stack, 'Cooccurrence');
    _data.markLoaded();
    onProgress?.call(1.0, '初始化失败，使用空数据');
  }
}
```

**Step 3: 添加必要的 import**

在文件顶部添加：
```dart
import 'package:flutter/services.dart';
```

**Step 4: 添加虚拟 SendPort 类（用于 Isolate 解析）**

在文件中的某个位置添加：
```dart
/// 虚拟 SendPort，用于不需要进度报告的 Isolate 解析
class _DummySendPort implements SendPort {
  @override
  void send(Object? message) {
    // 忽略进度消息
  }

  @override
  int get hashCode => 0;

  @override
  bool operator ==(Object other) => other is _DummySendPort;
}
```

**Step 5: Commit**

```bash
git add lib/core/services/cooccurrence_service.dart
git commit -m "feat(cooccurrence): 支持从本地 assets 加载共现数据"
```

---

## Task 2: 修复翻译服务加载所有 CSV 文件

**Files:**
- Modify: `lib/data/services/tag_translation_service.dart:140-155`

**Step 1: 修改 load() 方法，加载所有翻译数据源**

将现有的：
```dart
final tagCsvContent =
    await rootBundle.loadString('assets/translations/danbooru.csv');
```

修改为加载所有翻译文件：

```dart
// 加载所有翻译 CSV 文件
final csvFiles = [
  'assets/translations/danbooru.csv',           // 主要翻译
  'assets/translations/danbooru_zh.csv',        // 中文翻译
  'assets/translations/github_sanlvzhetang.csv', // GitHub 翻译
  'assets/translations/github_chening233.csv',   // Wiki 翻译
];

final csvContents = <String>[];
for (final file in csvFiles) {
  try {
    final content = await rootBundle.loadString(file);
    csvContents.add(content);
    AppLogger.d('Loaded translation file: $file', 'TagTranslation');
  } catch (e) {
    AppLogger.w('Failed to load translation file: $file - $e', 'TagTranslation');
  }
}

// 合并所有 CSV 内容
final tagCsvContent = csvContents.join('\n');
```

**Step 2: Commit**

```bash
git add lib/data/services/tag_translation_service.dart
git commit -m "feat(translation): 加载所有本地翻译 CSV 文件"
```

---

## Task 3: 修复 CSV 解析以处理不同格式

**Files:**
- Modify: `lib/data/services/tag_translation_service.dart:36-77`

**Step 1: 修改 Isolate 解析逻辑，处理不同 CSV 格式**

修改 `_parseAllCsvInIsolate` 函数：

```dart
_ParsedTranslationData _parseAllCsvInIsolate(_IsolateParseParams params) {
  final tagTranslations = <String, String>{};
  final characterTranslations = <String, String>{};

  // CSV 解析器配置 - 用于简单格式 (tag,translation)
  const simpleConverter = CsvToListConverter(
    fieldDelimiter: ',',
    textDelimiter: '"',
    textEndDelimiter: '"',
    eol: '\n',
    shouldParseNumbers: false,
  );

  // 解析标签翻译 CSV（可能包含多个文件内容）
  final tagRows = simpleConverter.convert(params.tagCsvContent);
  for (final row in tagRows) {
    if (row.length >= 2) {
      // 处理可能的引号包裹
      var englishTag = row[0].toString().trim().toLowerCase();
      var chineseTranslation = row[1].toString().trim();

      // 去除可能的引号
      if (englishTag.startsWith('"') && englishTag.endsWith('"')) {
        englishTag = englishTag.substring(1, englishTag.length - 1);
      }
      if (chineseTranslation.startsWith('"') && chineseTranslation.endsWith('"')) {
        chineseTranslation = chineseTranslation.substring(1, chineseTranslation.length - 1);
      }

      if (englishTag.isNotEmpty && chineseTranslation.isNotEmpty) {
        // 跳过标题行
        if (englishTag == 'tag' || englishTag == 'en' || englishTag == 'name') {
          continue;
        }
        tagTranslations[englishTag] = chineseTranslation;
      }
    }
  }

  // 解析角色翻译 CSV（格式：中文名,英文名）
  final charRows = simpleConverter.convert(params.charCsvContent);
  for (final row in charRows) {
    if (row.length >= 2) {
      var chineseName = row[0].toString().trim();
      var englishTag = row[1].toString().trim().toLowerCase();

      // 去除可能的引号
      if (chineseName.startsWith('"') && chineseName.endsWith('"')) {
        chineseName = chineseName.substring(1, chineseName.length - 1);
      }
      if (englishTag.startsWith('"') && englishTag.endsWith('"')) {
        englishTag = englishTag.substring(1, englishTag.length - 1);
      }

      if (englishTag.isNotEmpty && chineseName.isNotEmpty) {
        characterTranslations[englishTag] = chineseName;
      }
    }
  }

  return _ParsedTranslationData(
    tagTranslations: tagTranslations,
    characterTranslations: characterTranslations,
  );
}
```

**Step 2: Commit**

```bash
git add lib/data/services/tag_translation_service.dart
git commit -m "fix(translation): 改进 CSV 解析，处理不同格式和引号"
```

---

## Task 4: 清除旧缓存并测试

**Files:**
- Test: 运行应用检查日志输出

**Step 1: 添加缓存清除方法（开发调试用）**

可以在设置页面添加一个"清除翻译缓存"的按钮，或者临时在代码中添加：

```dart
// 在 TagTranslationService.load() 方法开头临时添加
await _cacheService.clearCache();
```

**Step 2: 运行应用并检查日志**

运行: `flutter run`

Expected:
- 日志应显示 `Loaded cooccurrence data from assets: X tags`
- 日志应显示 `Tag translations parsed: X tags`（数量应比之前多）
- `simple_background` 标签应该有中文翻译

**Step 3: Commit**

```bash
git add lib/data/services/tag_translation_service.dart
git commit -m "chore(translation): 清除旧缓存确保新数据加载"
```

---

## Task 5: 代码生成和验证

**Files:**
- All modified files

**Step 1: 运行代码生成**

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 2: 运行代码分析**

```bash
flutter analyze
```

Expected: 无错误

**Step 3: Commit**

```bash
git add .
git commit -m "chore: 运行代码生成"
```

---

## 最终验证清单

- [ ] 启动应用时不再显示"需要下载共现数据"
- [ ] 日志显示 `Loaded cooccurrence data from assets: X tags`
- [ ] `simple_background` 标签能正确显示中文翻译
- [ ] 其他标签（如 `white_background`, `outdoors`）翻译正常
