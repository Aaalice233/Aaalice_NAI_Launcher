# 优化共现数据加载流程实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一共现数据存储架构，使用 SQLite 作为主存储，CSV 仅作为数据源，实现首次导入、增量更新、快速启动

**Architecture:**
- **单一数据源**: SQLite 数据库作为主存储，替代二进制缓存+内存的双重结构
- **版本管理**: CSV 文件哈希比对，数据变化时自动重新导入
- **懒加载模式**: 不预加载全部数据到内存，查询时从 SQLite 读取
- **三阶段预热**: 预热阶段仅检查/初始化数据库，后台阶段处理 CSV 导入

**Tech Stack:** Flutter, Dart, Riverpod, SQLite (sqflite), crypto (哈希)

---

## 背景分析

### 当前问题

1. **存储格式混乱**: 同时维护二进制缓存、CSV文件、内存Map、SQLite 四种格式
2. **启动后卡顿**: 加载 103MB CSV 到内存时阻塞 UI
3. **数据未持久化**: CSV 加载到内存后未写入 SQLite，每次重启重复加载
4. **无法增量更新**: 缺少版本检测机制，无法判断 CSV 是否变化

### 目标架构

```
┌─────────────────────────────────────────────────────────────┐
│ 存储层: SQLite (统一存储)                                      │
│   ├── cooccurrences 表: 存储共现关系                            │
│   ├── metadata 表: 存储版本信息 (CSV哈希、导入时间)               │
└─────────────────────────────────────────────────────────────┘
                              ↑
                              │ 首次启动/更新时导入
┌─────────────────────────────────────────────────────────────┐
│ 数据源: Assets CSV 文件 (只读)                                 │
│   └── hf_danbooru_cooccurrence.csv                            │
└─────────────────────────────────────────────────────────────┘

启动流程:
预热阶段 Critical: 数据迁移
预热阶段 Quick:
  ├── 检查 SQLite 中是否有共现数据
  └── 计算 CSV 哈希，与数据库版本比对
↓
进入主界面
↓
后台任务:
  ├── 需要导入/更新时: CSV → SQLite (分批导入)
  └── 无需更新时: 跳过
```

---

## Task 1: 添加 CSV 哈希计算工具

**Files:**
- Create: `lib/core/utils/file_hash_utils.dart`

**Step 1: 创建文件哈希工具类**

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

/// 文件哈希工具类
class FileHashUtils {
  /// 计算文件的 SHA256 哈希（流式，适合大文件）
  static Future<String> calculateFileHash(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final sink = sha256.startChunkedConversion(BytesBuilder());
    final stream = file.openRead();

    await for (final chunk in stream) {
      sink.add(Uint8List.fromList(chunk));
    }

    sink.close();
    final bytes = (sink as dynamic).bytes as List<int>;
    return base64Encode(bytes);
  }

  /// 计算 Asset 文件的 SHA256 哈希
  static Future<String> calculateAssetHash(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final buffer = bytes.buffer.asUint8List();
    final hash = sha256.convert(buffer);
    return base64Encode(hash.bytes);
  }

  /// 计算字符串的 SHA256 哈希
  static String calculateStringHash(String content) {
    final bytes = utf8.encode(content);
    final hash = sha256.convert(bytes);
    return base64Encode(hash.bytes);
  }
}
```

**Step 2: 运行代码分析**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/core/utils/file_hash_utils.dart
```

Expected: No issues found

**Step 3: Commit**

```bash
git add lib/core/utils/file_hash_utils.dart
git commit -m "feat(utils): 添加文件哈希计算工具"
```

---

## Task 2: 扩展 metadata 表支持 CSV 版本追踪

**Files:**
- Modify: `lib/core/services/unified_tag_database.dart`

**Step 1: 在 UnifiedTagDatabase 中添加版本管理方法**

```dart
/// 获取 CSV 数据源版本信息
Future<Map<String, dynamic>?> getDataSourceVersion(String sourceName) async {
  try {
    final db = await _getDb();
    final result = await db.query(
      'metadata',
      columns: ['data_version', 'last_updated', 'extra_data'],
      where: 'source = ?',
      whereArgs: [sourceName],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final row = result.first;
    final extraData = row['extra_data'] as String?;

    return {
      'version': row['data_version'] as int? ?? 0,
      'lastUpdated': row['last_updated'] as String?,
      'extraData': extraData != null ? jsonDecode(extraData) : null,
    };
  } catch (e) {
    AppLogger.w('Failed to get data source version: $e', 'UnifiedTagDatabase');
    return null;
  }
}

/// 更新 CSV 数据源版本信息
Future<void> updateDataSourceVersion(
  String sourceName,
  int version, {
  String? hash,
  Map<String, dynamic>? extraData,
}) async {
  try {
    final db = await _getDb();
    final extra = extraData != null ? jsonEncode(extraData) : null;

    await db.insert(
      'metadata',
      {
        'source': sourceName,
        'data_version': version,
        'last_updated': DateTime.now().toIso8601String(),
        'extra_data': extra ?? (hash != null ? jsonEncode({'hash': hash}) : null),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    AppLogger.i('Updated $sourceName version to $version', 'UnifiedTagDatabase');
  } catch (e) {
    AppLogger.w('Failed to update data source version: $e', 'UnifiedTagDatabase');
  }
}

/// 检查共现数据是否需要更新
Future<bool> needsCooccurrenceUpdate(String csvHash) async {
  final version = await getDataSourceVersion('cooccurrence_csv');
  if (version == null) return true;

  final storedHash = version['extraData']?['hash'] as String?;
  return storedHash != csvHash;
}
```

**Step 2: 确保 metadata 表结构支持 extra_data**

检查数据库初始化 SQL，确保 `metadata` 表已创建：

```dart
// 在数据库初始化方法中确认
await db.execute('''
  CREATE TABLE IF NOT EXISTS metadata (
    source TEXT PRIMARY KEY,
    data_version INTEGER NOT NULL DEFAULT 0,
    last_updated TEXT,
    extra_data TEXT
  )
''');
```

**Step 3: 运行代码分析**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/core/services/unified_tag_database.dart
```

**Step 4: Commit**

```bash
git add lib/core/services/unified_tag_database.dart
git commit -m "feat(database): 添加 CSV 版本追踪支持"
```

---

## Task 3: 实现 CSV 分批导入 SQLite 功能

**Files:**
- Modify: `lib/core/services/cooccurrence_service.dart`

**Step 1: 添加 CSV 导入方法**

```dart
/// 将 Assets 中的 CSV 导入 SQLite（分批处理，避免阻塞）
///
/// 返回: 导入的记录数，-1 表示失败
Future<int> importCsvToSQLite({
  void Function(double progress, String message)? onProgress,
}) async {
  if (_unifiedDb == null) {
    throw StateError('UnifiedTagDatabase not initialized');
  }

  final stopwatch = Stopwatch()..start();
  onProgress?.call(0.0, '读取 CSV 文件...');

  try {
    // 1. 读取 CSV 内容
    final csvContent = await rootBundle.loadString(
      'assets/translations/hf_danbooru_cooccurrence.csv',
    );

    onProgress?.call(0.1, '解析数据...');

    // 2. 解析 CSV（在 Isolate 中）
    final lines = await Isolate.run(() => csvContent.split('\n'));
    final totalLines = lines.length;

    onProgress?.call(0.2, '准备导入...');

    // 3. 清空旧数据
    await _unifiedDb!.clearCooccurrences();

    // 4. 分批导入
    const batchSize = 5000;
    var processedCount = 0;
    var importedCount = 0;
    final records = <CooccurrenceRecord>[];

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;

      // 跳过表头
      if (i == 0 && line.contains(',')) continue;

      // 去除引号
      if (line.startsWith('"') && line.endsWith('"')) {
        line = line.substring(1, line.length - 1);
      }

      final parts = line.split(',');
      if (parts.length >= 3) {
        final tag1 = parts[0].trim().toLowerCase();
        final tag2 = parts[1].trim().toLowerCase();
        final countStr = parts[2].trim();
        final count = double.tryParse(countStr)?.toInt() ?? 0;

        if (tag1.isNotEmpty && tag2.isNotEmpty && count > 0) {
          records.add(CooccurrenceRecord(
            tag1: tag1,
            tag2: tag2,
            count: count,
            cooccurrenceScore: 0.0,
          ));
        }
      }

      // 达到批次大小，执行导入
      if (records.length >= batchSize) {
        await _unifiedDb!.insertCooccurrences(records);
        importedCount += records.length;
        records.clear();

        // 更新进度
        processedCount = i;
        final progress = 0.2 + (processedCount / totalLines) * 0.7;
        onProgress?.call(
          progress,
          '导入中... ${(progress * 100).toInt()}%',
        );

        // 让出时间片，避免阻塞 UI
        await Future.delayed(Duration.zero);
      }
    }

    // 导入剩余记录
    if (records.isNotEmpty) {
      await _unifiedDb!.insertCooccurrences(records);
      importedCount += records.length;
    }

    onProgress?.call(1.0, '导入完成');

    stopwatch.stop();
    AppLogger.i(
      'Cooccurrence CSV imported: $importedCount records in ${stopwatch.elapsedMilliseconds}ms',
      'Cooccurrence',
    );

    return importedCount;
  } catch (e, stack) {
    AppLogger.e('Failed to import CSV to SQLite', e, stack, 'Cooccurrence');
    onProgress?.call(1.0, '导入失败');
    return -1;
  }
}
```

**Step 2: 添加完整的初始化流程**

```dart
/// 统一的初始化流程：检查 → 导入 → 完成
///
/// 返回: true 表示数据已就绪，false 表示需要后台导入
Future<bool> initializeUnified() async {
  AppLogger.i('Initializing cooccurrence (unified)...', 'Cooccurrence');
  final stopwatch = Stopwatch()..start();

  try {
    // 1. 确保数据库已初始化
    if (_unifiedDb == null) {
      throw StateError('UnifiedTagDatabase not initialized');
    }
    if (!_unifiedDb!.isInitialized) {
      await _unifiedDb!.initialize();
    }

    // 2. 检查 SQLite 中是否已有数据
    final counts = await _unifiedDb!.getRecordCounts();
    if (counts.cooccurrences > 0) {
      // 有数据，检查版本
      final csvHash = await FileHashUtils.calculateAssetHash(
        'assets/translations/hf_danbooru_cooccurrence.csv',
      );

      final needsUpdate = await _unifiedDb!.needsCooccurrenceUpdate(csvHash);

      if (!needsUpdate) {
        // 数据最新，直接使用
        _loadMode = CooccurrenceLoadMode.sqlite;
        _data.markLoaded();
        stopwatch.stop();
        AppLogger.i(
          'Cooccurrence data up to date, using SQLite (${counts.cooccurrences} records) in ${stopwatch.elapsedMilliseconds}ms',
          'Cooccurrence',
        );
        return true;
      } else {
        // 需要更新，标记后后台处理
        AppLogger.i('Cooccurrence data needs update', 'Cooccurrence');
        _loadMode = CooccurrenceLoadMode.sqlite;
        _data.markLoaded();
        return false; // 需要后台更新
      }
    }

    // 3. 数据库为空，需要首次导入
    AppLogger.i('Cooccurrence database empty, needs initial import', 'Cooccurrence');
    _loadMode = CooccurrenceLoadMode.sqlite;
    return false; // 需要后台导入
  } catch (e, stack) {
    AppLogger.e('Cooccurrence unified init failed', e, stack, 'Cooccurrence');
    _data.markLoaded();
    return false;
  }
}

/// 后台执行 CSV 导入（带版本更新）
Future<void> performBackgroundImport({
  void Function(double progress, String message)? onProgress,
}) async {
  try {
    // 1. 执行导入
    final imported = await importCsvToSQLite(onProgress: onProgress);

    if (imported > 0) {
      // 2. 更新版本信息
      final csvHash = await FileHashUtils.calculateAssetHash(
        'assets/translations/hf_danbooru_cooccurrence.csv',
      );

      await _unifiedDb!.updateDataSourceVersion(
        'cooccurrence_csv',
        1, // 版本号
        hash: csvHash,
        extraData: {
          'importedAt': DateTime.now().toIso8601String(),
          'recordCount': imported,
        },
      );

      _data.markLoaded();
      AppLogger.i('Cooccurrence background import completed', 'Cooccurrence');
    }
  } catch (e, stack) {
    AppLogger.e('Background import failed', e, stack, 'Cooccurrence');
  }
}
```

**Step 3: 修改查询方法使用 SQLite**

```dart
Future<List<RelatedTag>> getRelatedTags(String tag, {int limit = 20}) async {
  // 统一使用 SQLite 模式
  if (_unifiedDb != null) {
    final results = await _unifiedDb!.getRelatedTags(tag, limit: limit);
    return results
        .map((r) => RelatedTag(
              tag: r.tag,
              count: r.count,
              cooccurrenceScore: r.cooccurrenceScore,
            ))
        .toList();
  }

  // 降级到内存数据
  return _data.getRelatedTags(tag, limit: limit);
}
```

**Step 4: 运行代码分析**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/core/services/cooccurrence_service.dart
```

**Step 5: Commit**

```bash
git add lib/core/services/cooccurrence_service.dart
git commit -m "feat(cooccurrence): 实现 CSV → SQLite 分批导入功能"
```

---

## Task 4: 修改 WarmupProvider 使用新的初始化流程

**Files:**
- Modify: `lib/presentation/providers/warmup_provider.dart`

**Step 1: 修改共现数据初始化方法**

```dart
Future<void> _initCooccurrenceData() async {
  AppLogger.i('开始初始化共现数据...', 'Warmup');

  final service = ref.read(cooccurrenceServiceProvider);
  final unifiedDb = ref.read(unifiedTagDatabaseProvider);

  try {
    // 设置数据库连接
    service.setUnifiedDatabase(unifiedDb);

    // 统一初始化流程
    final isReady = await service.initializeUnified().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        AppLogger.w('共现数据初始化超时', 'Warmup');
        return false;
      },
    );

    if (isReady) {
      AppLogger.i('共现数据已就绪（SQLite）', 'Warmup');
    } else {
      AppLogger.i('共现数据需要后台导入', 'Warmup');
    }
  } catch (e, stack) {
    AppLogger.e('共现数据初始化失败', e, stack, 'Warmup');
  }
}
```

**Step 2: 修改后台任务执行导入**

```dart
Future<void> _checkAndImportCooccurrence() async {
  final service = ref.read(cooccurrenceServiceProvider);

  service.onProgress = (progress, message) {
    ref
        .read(backgroundTaskNotifierProvider.notifier)
        .updateProgress('cooccurrence_import', progress, message: message);
  };

  await service.performBackgroundImport(onProgress: service.onProgress);

  service.onProgress = null;
}
```

**Step 3: 修改后台任务注册**

```dart
void _registerBackgroundPhaseTasks() {
  final backgroundNotifier = ref.read(backgroundTaskNotifierProvider.notifier);

  // 共现数据导入/更新（如果需要）
  final service = ref.read(cooccurrenceServiceProvider);
  // 只在需要时注册任务
  backgroundNotifier.registerTask(
    'cooccurrence_import',
    '共现数据导入',
    () => _checkAndImportCooccurrence(),
  );

  // 翻译数据后台加载
  backgroundNotifier.registerTask(
    'translation_preload',
    '翻译数据',
    () => _preloadTranslationInBackground(),
  );

  // Danbooru标签后台加载
  backgroundNotifier.registerTask(
    'danbooru_tags_preload',
    '标签数据',
    () => _preloadDanbooruTagsInBackground(),
  );
}
```

**Step 4: 运行代码分析**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/presentation/providers/warmup_provider.dart
```

**Step 5: Commit**

```bash
git add lib/presentation/providers/warmup_provider.dart
git commit -m "refactor(warmup): 使用新的共现数据初始化流程"
```

---

## Task 5: 生成代码并完整测试

**Step 1: 生成 Riverpod 代码**

```bash
/mnt/e/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs
```

**Step 2: 完整代码分析**

```bash
/mnt/e/flutter/bin/flutter.bat analyze
```

Expected: No issues found

**Step 3: 运行 dart fix**

```bash
/mnt/e/flutter/bin/dart.bat fix --apply
```

**Step 4: 最终分析确认**

```bash
/mnt/e/flutter/bin/flutter.bat analyze
```

Expected: No issues found

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: 生成 Riverpod 代码"
```

---

## 测试计划

### 测试 1: 首次启动导入

1. **清理环境**
   ```powershell
   Remove-Item -Recurse -Force "$env:APPDATA\com.example\nai_launcher"
   ```

2. **启动应用**
   - 预热阶段应显示"共现数据需要后台导入"
   - 进入主界面后应看到后台任务"共现数据导入"进度

3. **验证导入完成**
   - 查看日志: `Cooccurrence CSV imported: X records`
   - 检查数据库: metadata 表应有 cooccurrence_csv 记录

### 测试 2: 二次启动（快速启动）

1. **关闭应用后重启**

2. **验证快速启动**
   - 日志应显示: `Cooccurrence data up to date, using SQLite`
   - 不应出现 CSV 导入进度条
   - 启动时间应 < 2 秒

3. **验证共现功能**
   - 立即输入标签，共现建议应立即可用

### 测试 3: CSV 更新检测

1. **模拟 CSV 变化**
   - 修改代码中的哈希计算，返回不同值（测试用）

2. **启动应用**
   - 应检测到需要更新: `Cooccurrence data needs update`
   - 后台应重新导入数据

### 测试 4: 内存占用测试

1. **使用任务管理器观察**
   - 旧方案: 启动后内存占用 +100MB+（全部加载到内存）
   - 新方案: 启动后内存占用 +10MB（仅 SQLite 缓存）

---

## 回滚计划

如果出现问题：

```bash
# 回滚到计划开始前的状态
git revert HEAD~5..HEAD
```

或者只回滚部分提交：

```bash
# 只回滚 CooccurrenceService 的修改
git revert <commit-hash>
```

---

## 性能对比预期

| 指标 | 旧方案 | 新方案 |
|------|--------|--------|
| 首次启动 | 10-15s | 15-20s（后台导入） |
| 二次启动 | 10-15s | 1-2s |
| 内存占用 | 100MB+ | 10-20MB |
| 共现查询 | 内存Map O(1) | SQLite O(log n) |
| 数据更新 | 重新下载 | 哈希比对，增量更新 |

---

## Task 6: 删除下载共现标签 CSV 功能

**Files:**
- Modify: `lib/core/services/cooccurrence_service.dart`

**Step 1: 删除下载相关代码**

找到并删除以下内容：
- `_baseUrl` 常量（HuggingFace URL）
- `_fileName` 常量
- `download()` 方法（整个方法，约 70 行）
- `Dio` 导入（如果只用于下载）
- `onDownloadProgress` 回调
- `_isDownloading` 字段（如不再使用）
- `DownloadMessageKeys` 导入（如果只在下载中使用）

**Step 2: 简化构造函数**

```dart
// 删除 Dio 依赖后的简化版本
CooccurrenceService() {
  unawaited(_loadMeta());
}
```

**Step 3: 删除 Provider 中的 Dio 配置**

```dart
// 简化后的 Provider
@Riverpod(keepAlive: true)
CooccurrenceService cooccurrenceService(Ref ref) {
  return CooccurrenceService();  // 不再需要 Dio
}
```

**Step 4: 运行代码分析**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/core/services/cooccurrence_service.dart
```

Expected: No issues found

**Step 5: Commit**

```bash
git add lib/core/services/cooccurrence_service.dart
git commit -m "refactor(cooccurrence): 删除下载 CSV 功能，仅使用本地 Assets"
```

---

## Task 7: 清理旧代码（二进制缓存、内存Map等）

**Files:**
- Modify: `lib/core/services/cooccurrence_service.dart`

**Step 1: 删除二进制缓存相关代码**

删除以下内容：
- `_binaryCacheFileName` 常量
- `_binaryCacheVersion` 常量
- `_binaryCacheMagic` 常量
- `_getCacheDir()` 方法（如果不再使用）
- `_getCacheFile()` 方法（如果不再使用）
- `_getBinaryCacheFile()` 方法
- `_saveToBinaryCache()` 方法
- `_loadFromBinaryCache()` 方法
- `_generateBinaryCache()` 方法
- `ChunkedCooccurrenceLoader` 类
- `_loadFromFileChunked()` 方法

**Step 2: 简化 CooccurrenceData 类**

新的简化版本只保留必要的内存缓存：

```dart
/// 共现数据内存缓存（热标签）
class CooccurrenceData {
  final Map<String, Map<String, int>> _cooccurrenceMap = {};
  final Set<String> _loadedTags = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get loadedTagCount => _loadedTags.length;

  List<RelatedTag> getRelatedTags(String tag, {int limit = 20}) {
    final normalizedTag = tag.toLowerCase().trim();
    final related = _cooccurrenceMap[normalizedTag];

    if (related == null || related.isEmpty) {
      return [];
    }

    final sortedEntries = related.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries
        .take(limit)
        .map((e) => RelatedTag(tag: e.key, count: e.value))
        .toList();
  }

  void addCooccurrence(String tag1, String tag2, int count) {
    final t1 = tag1.toLowerCase().trim();
    final t2 = tag2.toLowerCase().trim();

    _cooccurrenceMap.putIfAbsent(t1, () => {})[t2] = count;
    _cooccurrenceMap.putIfAbsent(t2, () => {})[t1] = count;
  }

  void markLoaded() {
    _isLoaded = true;
  }

  void clear() {
    _cooccurrenceMap.clear();
    _loadedTags.clear();
    _isLoaded = false;
  }
}
```

**Step 3: 删除未使用的导入和枚举**

删除：
- `CooccurrenceLoadMode` 枚举（不再需要）
- `CooccurrenceLoadStage` 枚举（如果不再使用）
- 未使用的 `Dio` 相关导入（如果只在 download 中使用）

**Step 4: 简化接口方法**

只保留以下公共方法：
- `initializeUnified()` - 统一初始化
- `performBackgroundImport()` - 后台导入
- `getRelatedTags()` - 查询共现标签
- `getRelatedTagsForMultiple()` - 批量查询
- `clearCache()` - 清空缓存
- `shouldRefresh()` - 检查是否需要刷新

删除：
- `initialize()` - 旧初始化方法
- `initializeLightweight()` - 被 `initializeUnified` 替代
- `preloadHotDataInBackground()` - 不再需要
- `download()` - 如果不再需要网络下载
- 所有二进制缓存相关方法

**Step 5: 运行代码分析**

```bash
/mnt/e/flutter/bin/flutter.bat analyze lib/core/services/cooccurrence_service.dart
```

Expected: No issues found (可能会有未使用变量的警告，需要处理)

**Step 6: Commit**

```bash
git add lib/core/services/cooccurrence_service.dart
git commit -m "refactor(cooccurrence): 清理二进制缓存和旧代码，简化实现"
```

---

## Task 8: 最终验证和提交

**Step 1: 完整代码分析**

```bash
cmd.exe /c "cd /d E:\\Aaalice_NAI_Launcher && E:\\flutter\\bin\\flutter.bat analyze"
```

Expected: No issues found

**Step 2: 生成 Riverpod 代码**

```bash
/mnt/e/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs
```

**Step 3: 最终分析确认**

```bash
/mnt/e/flutter/bin/flutter.bat analyze
```

Expected: No issues found

**Step 4: Commit 所有更改**

```bash
git add -A
git commit -m "feat(cooccurrence): 统一 SQLite 存储架构，实现快速启动"
```

---

## 清理清单（重构后检查）

确保以下旧代码已被删除：

- [ ] 二进制缓存文件相关常量和路径
- [ ] `_saveToBinaryCache()` 方法
- [ ] `_loadFromBinaryCache()` 方法
- [ ] `_generateBinaryCache()` 方法
- [ ] `ChunkedCooccurrenceLoader` 类
- [ ] `_loadFromFileChunked()` 方法
- [ ] 旧的 `initialize()` 初始化方法
- [ ] `CooccurrenceLoadMode` 枚举（如不再使用）
- [ ] 未使用的 Dio 下载相关代码（如果只使用本地 CSV）
- [ ] 内存中加载全部数据的逻辑（改为 SQLite 查询）

---

## 后续优化建议

1. **预构建数据库**: 在构建 APK 时预生成 SQLite 数据库，避免首次导入
2. **索引优化**: 为 cooccurrences 表添加索引优化查询性能
3. **异步查询**: 共现查询使用异步 Stream，避免阻塞 UI
4. **压缩存储**: 对共现数据使用压缩存储减少磁盘占用
