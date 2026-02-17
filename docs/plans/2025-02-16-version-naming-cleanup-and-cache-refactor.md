# 版本号命名规范化 + 数据源缓存重构实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 移除项目中所有版本号命名（如 `_v2`），替换为语义化命名；重构数据源缓存清除功能，改为清空表数据而非删除文件，避免 Windows 文件锁定问题。

**Architecture:** 通过重命名文件、常量、类名消除版本号；新增 `DataSourceValidator` 类检测数据完整性；修改 `deleteDatabase()` 为 `clearAllTables()` 实现非破坏性数据清除。

**Tech Stack:** Flutter, Dart, SQLite (sqflite), Hive, Riverpod

---

## 任务清单总览

### Phase 1: 版本号命名规范化
1. [ ] 重命名数据库文件 `tag_data_v2.db` → `tag_data.db`
2. [ ] 重命名 Dart 文件 `vibe_reference_v4.dart` → `vibe_reference.dart`
3. [ ] 更新 Hive Box 名称（去除版本号后缀）
4. [ ] 更新迁移键名称（去除版本号后缀）
5. [ ] 更新所有导入语句

### Phase 2: 数据源缓存重构
6. [ ] 新增 `DataSourceValidator` 数据完整性检测类
7. [ ] 修改 `TagDatabaseConnection.deleteDatabase()` → `clearAllTables()`
8. [ ] 修改 UI 层 `_clearAllCaches()` 调用新 API

### Phase 3: 文档更新
9. [ ] 更新 `CLAUDE.md` 添加命名规范说明

---

## Task 1: 重命名数据库文件常量

**Files:**
- Modify: `lib/core/services/tag_database_connection.dart:19`

**Step 1: 修改数据库文件名**

```dart
// Before:
static const String _databaseName = 'tag_data_v2.db';

// After:
static const String _databaseName = 'tag_data.db';
```

**Step 2: 验证文件存在性检查日志**

确认 `_onUpgrade` 方法中的 v2 升级日志文本保留（这是历史记录，不是命名）：
```dart
AppLogger.i('Upgrading to v2: Recreating cooccurrences table without foreign keys', ...);
```

**Step 3: 运行代码生成**

```bash
FLUTTER="/mnt/e/flutter/bin/flutter.bat"
$FLUTTER analyze lib/core/services/tag_database_connection.dart
```
Expected: 无错误

**Step 4: Commit**

```bash
git add lib/core/services/tag_database_connection.dart
git commit -m "refactor: 重命名数据库文件 tag_data_v2.db → tag_data.db"
```

---

## Task 2: 重命名 vibe_reference_v4.dart 文件及类名

**Files:**
- Rename: `lib/data/models/vibe/vibe_reference_v4.dart` → `lib/data/models/vibe/vibe_reference.dart`
- Rename: `lib/data/models/vibe/vibe_reference_v4.freezed.dart` → `lib/data/models/vibe/vibe_reference.freezed.dart`
- Modify: 所有导入该文件的代码（约 15 个文件）

**Step 1: 修改类定义文件**

`lib/data/models/vibe/vibe_reference.dart`:
```dart
// Before:
part 'vibe_reference_v4.freezed.dart';
class VibeReferenceV4 with _$VibeReferenceV4 { ... }

// After:
part 'vibe_reference.freezed.dart';
class VibeReference with _$VibeReference { ... }
```

**Step 2: 运行 build_runner 更新生成文件**

```bash
DART="/mnt/e/flutter/bin/dart.bat"
$DART run build_runner build --delete-conflicting-outputs
```

**Step 3: 删除旧文件**

```bash
rm lib/data/models/vibe/vibe_reference_v4.dart
rm lib/data/models/vibe/vibe_reference_v4.freezed.dart
```

**Step 4: 更新所有导入语句**

使用全局替换修改以下文件中的导入：
- `lib/core/network/request_builders/nai_image_request_builder.dart`
- `lib/core/utils/vibe_encoding_utils.dart`
- `lib/core/utils/vibe_export_utils.dart`
- `lib/core/utils/vibe_file_parser.dart`
- `lib/core/utils/vibe_image_embedder.dart`
- `lib/data/models/vibe/vibe_library_entry.dart`
- `lib/data/models/image/image_params.dart`
- `lib/data/models/gallery/generation_record.dart`
- `lib/data/models/gallery/local_image_record.dart`
- `lib/data/services/vibe_file_storage_service.dart`
- `lib/data/services/vibe_import_service.dart`
- `lib/data/services/vibe_library_migration_service.dart`
- `lib/data/services/vibe_metadata_service.dart`
- `lib/data/services/gallery/gallery_database_service.dart`
- `lib/presentation/providers/generation/generation_params_notifier.dart`
- `lib/presentation/screens/vibe_library/widgets/vibe_selector_dialog.dart`
- `lib/presentation/screens/vibe_library/widgets/vibe_detail/vibe_detail_param_panel.dart`
- `lib/presentation/screens/vibe_library/widgets/vibe_export_dialog.dart`
- `lib/presentation/screens/generation/widgets/unified_reference_panel.dart`
- `lib/presentation/screens/gallery/gallery_screen.dart`
- `lib/presentation/widgets/drop/image_destination_dialog.dart`
- `lib/presentation/widgets/drop/global_drop_handler.dart`

替换模式：
```dart
// Before:
import '../models/vibe/vibe_reference_v4.dart';
import '../../data/models/vibe/vibe_reference_v4.dart';
import '../../../data/models/vibe/vibe_reference_v4.dart';
VibeReferenceV4

// After:
import '../models/vibe/vibe_reference.dart';
import '../../data/models/vibe/vibe_reference.dart';
import '../../../data/models/vibe/vibe_reference.dart';
VibeReference
```

**Step 5: 运行分析检查**

```bash
$FLUTTER analyze
```
Expected: 无错误

**Step 6: Commit**

```bash
git add .
git commit -m "refactor: 重命名 VibeReferenceV4 → VibeReference，移除版本号后缀"
```

---

## Task 3: 更新 Hive Box 名称

**Files:**
- Modify: `lib/data/services/vibe_library_storage_service.dart:47-48`
- Modify: `lib/data/services/gallery_migration_service.dart:18`
- Modify: `lib/data/repositories/gallery_repository.dart:22`

**Step 1: 更新 Vibe Library Storage Service**

`lib/data/services/vibe_library_storage_service.dart`:
```dart
// Before:
static const String _entriesBoxName = 'vibe_library_entries';
static const String _entriesFallbackBoxName = 'vibe_library_entries_v2';
static const String _entriesEmergencyBoxName = 'vibe_library_entries_v3';

// After:
static const String _entriesBoxName = 'vibe_library_entries';
static const String _entriesFallbackBoxName = 'vibe_library_entries_fallback';
static const String _entriesEmergencyBoxName = 'vibe_library_entries_emergency';
```

**Step 2: 更新 Gallery Migration Service**

`lib/data/services/gallery_migration_service.dart`:
```dart
// Before:
static const String _newBoxName = '${StorageKeys.galleryBox}_v2';

// After:
static const String _newBoxName = StorageKeys.galleryBox;
```

**Step 3: 更新 Gallery Repository**

`lib/data/repositories/gallery_repository.dart`:
```dart
// Before:
static const String _boxName = '${StorageKeys.galleryBox}_v2';

// After:
static const String _boxName = StorageKeys.galleryBox;
```

**Step 4: 运行分析**

```bash
$FLUTTER analyze lib/data/services/vibe_library_storage_service.dart lib/data/services/gallery_migration_service.dart lib/data/repositories/gallery_repository.dart
```
Expected: 无错误

**Step 5: Commit**

```bash
git add lib/data/services/vibe_library_storage_service.dart lib/data/services/gallery_migration_service.dart lib/data/repositories/gallery_repository.dart
git commit -m "refactor: 重命名 Hive Box，使用语义化命名替代版本号后缀"
```

---

## Task 4: 更新迁移键名称

**Files:**
- Modify: `lib/core/services/tag_database_migration.dart:40`
- Modify: `lib/data/services/gallery/gallery_migration_service.dart:36`

**Step 1: 更新 Tag Database Migration**

`lib/core/services/tag_database_migration.dart`:
```dart
// Before:
static const String _migrationVersionKey = 'tag_database_migration_v2';

// After:
static const String _migrationVersionKey = 'tag_database_migration';
```

**Step 2: 更新 Gallery Migration Service**

`lib/data/services/gallery/gallery_migration_service.dart`:
```dart
// Before:
static const String _migrationCompleteKey = 'gallery_migration_v1_complete';

// After:
static const String _migrationCompleteKey = 'gallery_migration_complete';
```

**Step 3: Commit**

```bash
git add lib/core/services/tag_database_migration.dart lib/data/services/gallery/gallery_migration_service.dart
git commit -m "refactor: 重命名迁移键，移除版本号后缀"
```

---

## Task 5: 新增 DataSourceValidator 数据完整性检测类

**Files:**
- Create: `lib/core/services/data_source_validator.dart`

**Step 1: 创建新文件**

```dart
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import '../utils/app_logger.dart';
import 'tag_database_connection.dart';

/// 数据源验证结果
class DataSourceStatus {
  final bool danbooruTags;
  final bool translations;
  final bool cooccurrences;
  final int danbooruTagCount;
  final int translationCount;
  final int cooccurrenceCount;

  const DataSourceStatus({
    required this.danbooruTags,
    required this.translations,
    required this.cooccurrences,
    this.danbooruTagCount = 0,
    this.translationCount = 0,
    this.cooccurrenceCount = 0,
  });

  bool get isComplete => danbooruTags && translations && cooccurrences;

  bool get needsRebuild => !danbooruTags || !translations;
}

/// 数据源完整性验证器
///
/// 用于检测各数据源的完整性，确保数据可用
class DataSourceValidator {
  final TagDatabaseConnection _connection;

  DataSourceValidator(this._connection);

  /// 验证所有数据源
  Future<DataSourceStatus> validateAll() async {
    if (!_connection.isConnected) {
      AppLogger.w('Database not connected, cannot validate', 'DataSourceValidator');
      return const DataSourceStatus(
        danbooruTags: false,
        translations: false,
        cooccurrences: false,
      );
    }

    final db = _connection.db!;

    final danbooruResult = await _validateDanbooruTags(db);
    final translationResult = await _validateTranslations(db);
    final cooccurrenceResult = await _validateCooccurrences(db);

    return DataSourceStatus(
      danbooruTags: danbooruResult.$1,
      translations: translationResult.$1,
      cooccurrences: cooccurrenceResult.$1,
      danbooruTagCount: danbooruResult.$2,
      translationCount: translationResult.$2,
      cooccurrenceCount: cooccurrenceResult.$2,
    );
  }

  /// 验证 Danbooru 标签数据
  /// 阈值：至少 10000 条记录才算完整
  Future<(bool, int)> _validateDanbooruTags(Database db) async {
    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM danbooru_tags');
      final count = result.first['count'] as int? ?? 0;
      final isValid = count >= 10000;
      AppLogger.i('Danbooru tags count: $count (valid: $isValid)', 'DataSourceValidator');
      return (isValid, count);
    } catch (e) {
      AppLogger.w('Failed to validate danbooru_tags: $e', 'DataSourceValidator');
      return (false, 0);
    }
  }

  /// 验证翻译数据
  /// 阈值：至少 1000 条记录
  Future<(bool, int)> _validateTranslations(Database db) async {
    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM translations');
      final count = result.first['count'] as int? ?? 0;
      final isValid = count >= 1000;
      AppLogger.i('Translations count: $count (valid: $isValid)', 'DataSourceValidator');
      return (isValid, count);
    } catch (e) {
      AppLogger.w('Failed to validate translations: $e', 'DataSourceValidator');
      return (false, 0);
    }
  }

  /// 验证共现数据
  /// 阈值：至少 1000 条记录（共现数据是可选增强功能）
  Future<(bool, int)> _validateCooccurrences(Database db) async {
    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM cooccurrences');
      final count = result.first['count'] as int? ?? 0;
      final isValid = count >= 1000;
      AppLogger.i('Cooccurrences count: $count (valid: $isValid)', 'DataSourceValidator');
      return (isValid, count);
    } catch (e) {
      AppLogger.w('Failed to validate cooccurrences: $e', 'DataSourceValidator');
      return (false, 0);
    }
  }
}
```

**Step 2: Commit**

```bash
git add lib/core/services/data_source_validator.dart
git commit -m "feat: 新增 DataSourceValidator 数据完整性检测类"
```

---

## Task 6: 修改 TagDatabaseConnection 清除逻辑

**Files:**
- Modify: `lib/core/services/tag_database_connection.dart:114-137`

**Step 1: 替换 deleteDatabase() 方法为 clearAllTables()**

```dart
// 删除整个 deleteDatabase() 方法，替换为：

/// 清空所有数据表（用于"清除缓存"功能）
/// 相比删除文件，此方法避免 Windows 文件锁定问题
Future<void> clearAllTables() async {
  if (_db == null) {
    AppLogger.w('Database not connected, nothing to clear', 'TagDatabaseConnection');
    return;
  }

  AppLogger.i('Clearing all database tables...', 'TagDatabaseConnection');

  await _db!.transaction((txn) async {
    // 清空数据表（保留表结构）
    await txn.execute('DELETE FROM danbooru_tags');
    await txn.execute('DELETE FROM translations');
    await txn.execute('DELETE FROM cooccurrences');
    await txn.execute('DELETE FROM metadata');
  });

  // 执行 VACUUM 回收空间
  await _db!.execute('VACUUM');

  AppLogger.i('All tables cleared successfully', 'TagDatabaseConnection');
}

/// 清空指定数据源的表
Future<void> clearTable(String tableName) async {
  if (_db == null) {
    throw StateError('Database not connected');
  }

  // 验证表名有效性（防止 SQL 注入）
  final validTables = {'danbooru_tags', 'translations', 'cooccurrences', 'metadata'};
  if (!validTables.contains(tableName)) {
    throw ArgumentError('Invalid table name: $tableName');
  }

  await _db!.execute('DELETE FROM $tableName');
  AppLogger.i('Table $tableName cleared', 'TagDatabaseConnection');
}
```

**Step 2: 运行分析**

```bash
$FLUTTER analyze lib/core/services/tag_database_connection.dart
```
Expected: 无错误

**Step 3: Commit**

```bash
git add lib/core/services/tag_database_connection.dart
git commit -m "refactor: 删除 deleteDatabase()，新增 clearAllTables() 和 clearTable() 方法"
```

---

## Task 7: 修改 UI 层调用新 API

**Files:**
- Modify: `lib/presentation/screens/settings/widgets/data_source_cache_settings.dart:163-254`

**Step 1: 更新 _clearAllCaches 方法**

```dart
/// 清除 Danbooru 标签缓存
Future<void> _clearAllCaches(BuildContext context) async {
  final rootContext = context;
  BuildContext? dialogContextOrNull;

  if (!context.mounted) return;

  // 显示进度指示器
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      dialogContextOrNull = dialogCtx;
      return PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 32,
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '正在清除数据...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  await Future.delayed(const Duration(milliseconds: 100));

  try {
    // 清空数据库表（不清除文件）
    final dbConnection = ref.read(tagDatabaseConnectionProvider);
    await dbConnection.clearAllTables();

    // 清除内存缓存
    await ref.read(danbooruTagsCacheNotifierProvider.notifier).clearCache();

    // 刷新状态
    ref.invalidate(danbooruTagsCacheNotifierProvider);

    // 关闭进度对话框
    if (dialogContextOrNull != null && dialogContextOrNull!.mounted) {
      _closeDialog(dialogContextOrNull);
    }
    await Future.delayed(const Duration(milliseconds: 100));

    if (rootContext.mounted) {
      AppToast.success(rootContext, '标签数据已清除，下次启动时将重新加载');
    }
  } catch (e) {
    if (dialogContextOrNull != null && dialogContextOrNull!.mounted) {
      _closeDialog(dialogContextOrNull);
    }
    await Future.delayed(const Duration(milliseconds: 100));

    if (rootContext.mounted) {
      AppToast.error(rootContext, '清除失败: $e');
    }
  }
}
```

**Step 2: 更新对话框文本**

```dart
// 修改对话框内容（约第 107-118 行）
// Before:
title: const Text('清除标签数据源'),
content: Text(
  '确定要清除所有标签数据源吗？\n\n'
  '这将删除以下数据：\n'
  '• Danbooru 标签补全数据\n'
  '• 中英文标签翻译\n'
  '• 标签共现关系\n\n'
  '清除后下次启动时将自动重建数据库并恢复内置数据。',

// After:
title: const Text('清除标签数据源'),
content: Text(
  '确定要清除所有标签数据源吗？\n\n'
  '这将清空以下数据：\n'
  '• Danbooru 标签补全数据\n'
  '• 中英文标签翻译\n'
  '• 标签共现关系\n\n'
  '清除后下次启动时将自动重新加载数据。',
```

**Step 3: 运行分析**

```bash
$FLUTTER analyze lib/presentation/screens/settings/widgets/data_source_cache_settings.dart
```
Expected: 无错误

**Step 4: Commit**

```bash
git add lib/presentation/screens/settings/widgets/data_source_cache_settings.dart
git commit -m "refactor: 更新缓存清除 UI，使用 clearAllTables() 替代 deleteDatabase()"
```

---

## Task 8: 更新 CLAUDE.md 添加命名规范

**Files:**
- Modify: `CLAUDE.md` (在 Development Commands 后添加)

**Step 1: 添加命名规范章节**

在 `CLAUDE.md` 的 "## Code 规范" 小节后添加（如果没有则新建）：

```markdown
### 命名规范

**禁止使用版本号后缀命名**

不要将版本号（如 `_v2`, `_v3`）用于：
- 文件名（如 `tag_data_v2.db` → `tag_data.db`）
- 类名（如 `VibeReferenceV4` → `VibeReference`）
- 变量/常量名（如 `_entriesV2` → 使用语义化命名）
- Hive Box 名称

**例外情况**：
- API 参数名（如 NovelAI 的 `ddim_v3`）保留原样
- 本地化键表示产品特性版本（如 `vibe_sourceType_v4vibe`）
- 运行时版本管理变量（版本号是值，不是名称的一部分）

**正确做法**：
- 使用语义化命名（如 `_emergency`, `_fallback`）
- 数据库版本管理使用 `version` 字段或 `user_version` PRAGMA
- 需要迁移时通过版本号变量控制，而非文件复制

**原因**：
版本号命名会导致旧代码和死代码残留，维护困难。语义化命名更具可读性和可维护性。
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: 添加命名规范，禁止使用版本号后缀"
```

---

## 最终验证

**运行完整检查：**

```bash
$FLUTTER analyze
$DART run build_runner build --delete-conflicting-outputs
$FLUTTER analyze
```

**Expected:** 无错误

**测试检查清单：**
- [ ] 应用可以正常启动
- [ ] 数据库连接正常（检查日志）
- [ ] 标签补全功能正常工作
- [ ] 清除缓存按钮不再报错（Windows）
- [ ] Vibe Library 功能正常

---

## 迁移说明（给开发者）

**数据库迁移：**
由于数据库文件名从 `tag_data_v2.db` 改为 `tag_data.db`，老用户将自动创建新数据库文件。旧文件不会被自动删除（避免数据丢失），可以通过手动清理应用数据来删除。

**Hive Box 迁移：**
Box 名称变化后，旧数据将在新名称下重新创建。旧 Box 数据会保留在存储中但不影响功能。

**迁移键影响：**
迁移键名称变化可能导致某些迁移重新执行，但这是安全的（幂等操作）。
