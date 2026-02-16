import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'unified_tag_database.dart';

/// 确保 SQLite FFI 已初始化
void _ensureSqliteFfiInitialized() {
  try {
    databaseFactory;
  } catch (e) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppLogger.i('SQLite FFI re-initialized', 'TagDatabaseMigration');
  }
}

/// 迁移进度回调
typedef MigrationProgressCallback = void Function(
  String stage,
  double progress,
  String? message,
);

/// 标签数据库迁移服务
///
/// 负责将旧的独立存储迁移到统一的 UnifiedTagDatabase
/// 支持从以下源迁移：
/// - TranslationSqliteService (translation.db)
/// - DanbooruTagsSqliteService (danbooru_tags.db)
/// - CooccurrenceService (CSV/二进制文件)
/// - TagDataService (CSV文件)
class TagDatabaseMigration {
  static const String _migrationVersionKey = 'tag_database_migration';
  static const int _currentMigrationVersion = 1;

  /// 统一数据库
  final UnifiedTagDatabase _unifiedDb;

  /// 进度回调
  MigrationProgressCallback? onProgress;

  /// 是否正在迁移
  bool _isMigrating = false;

  bool get isMigrating => _isMigrating;

  TagDatabaseMigration(this._unifiedDb);

  /// 检查是否需要迁移
  Future<bool> needsMigration() async {
    // 1. 检查是否已完成迁移
    final prefs = await SharedPreferences.getInstance();
    final migratedVersion = prefs.getInt(_migrationVersionKey);
    if (migratedVersion == _currentMigrationVersion) {
      AppLogger.i('Tag database migration already completed', 'TagDatabaseMigration');
      return false;
    }

    // 2. 检查是否有旧数据需要迁移
    final hasOldData = await _hasOldData();
    if (!hasOldData) {
      // 没有旧数据，标记为已迁移
      await prefs.setInt(_migrationVersionKey, _currentMigrationVersion);
      return false;
    }

    return true;
  }

  /// 检查是否有旧数据
  Future<bool> _hasOldData() async {
    final appDir = await getApplicationSupportDirectory();

    // 检查旧数据库文件
    final oldDatabases = [
      path.join(appDir.path, 'databases', 'translation.db'),
      path.join(appDir.path, 'databases', 'danbooru_tags.db'),
      path.join(appDir.path, 'databases', 'cooccurrence.db'),
    ];

    for (final dbPath in oldDatabases) {
      if (await File(dbPath).exists()) {
        return true;
      }
    }

    // 检查旧 CSV 缓存
    final tagCacheDir = Directory('${appDir.path}/tag_cache');
    if (await tagCacheDir.exists()) {
      final files = await tagCacheDir.list().toList();
      if (files.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  /// 执行迁移
  ///
  /// 返回迁移结果：成功迁移的记录数
  Future<MigrationResult> migrate() async {
    if (_isMigrating) {
      throw StateError('Migration already in progress');
    }

    _isMigrating = true;
    final stopwatch = Stopwatch()..start();

    try {
      onProgress?.call('checking', 0.0, '检查迁移需求...');

      // 确保统一数据库已初始化
      if (!_unifiedDb.isInitialized) {
        await _unifiedDb.initialize();
      }

      int totalMigrated = 0;
      final results = <String, int>{};

      // 1. 迁移翻译数据
      onProgress?.call('translations', 0.1, '迁移翻译数据...');
      final translationCount = await _migrateTranslations();
      results['translations'] = translationCount;
      totalMigrated += translationCount;
      AppLogger.i('Migrated $translationCount translation records', 'TagDatabaseMigration');

      // 2. 迁移 Danbooru 标签
      onProgress?.call('danbooru_tags', 0.3, '迁移 Danbooru 标签...');
      final danbooruCount = await _migrateDanbooruTags();
      results['danbooru_tags'] = danbooruCount;
      totalMigrated += danbooruCount;
      AppLogger.i('Migrated $danbooruCount Danbooru tag records', 'TagDatabaseMigration');

      // 3. 迁移共现数据
      onProgress?.call('cooccurrences', 0.5, '迁移共现数据...');
      final cooccurrenceCount = await _migrateCooccurrences();
      results['cooccurrences'] = cooccurrenceCount;
      totalMigrated += cooccurrenceCount;
      AppLogger.i('Migrated $cooccurrenceCount cooccurrence records', 'TagDatabaseMigration');

      // 4. 验证数据完整性
      onProgress?.call('verifying', 0.8, '验证数据完整性...');
      final verified = await _verifyMigration(results);

      if (!verified) {
        AppLogger.w('Migration verification failed', 'TagDatabaseMigration');
        return MigrationResult(
          success: false,
          totalMigrated: totalMigrated,
          details: results,
          error: '数据验证失败',
        );
      }

      // 5. 标记迁移完成
      onProgress?.call('completing', 0.9, '完成迁移...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_migrationVersionKey, _currentMigrationVersion);

      // 6. 清理旧数据（可选，这里先保留）
      // await _cleanupOldData();

      stopwatch.stop();
      onProgress?.call('complete', 1.0, '迁移完成');

      AppLogger.i(
        'Tag database migration completed: $totalMigrated records in ${stopwatch.elapsedMilliseconds}ms',
        'TagDatabaseMigration',
      );

      return MigrationResult(
        success: true,
        totalMigrated: totalMigrated,
        details: results,
        duration: stopwatch.elapsed,
      );
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.e('Tag database migration failed', e, stack, 'TagDatabaseMigration');
      onProgress?.call('error', 1.0, '迁移失败: $e');

      return MigrationResult(
        success: false,
        totalMigrated: 0,
        details: {},
        error: e.toString(),
        duration: stopwatch.elapsed,
      );
    } finally {
      _isMigrating = false;
    }
  }

  /// 迁移翻译数据
  Future<int> _migrateTranslations() async {
    final appDir = await getApplicationSupportDirectory();
    final oldDbPath = path.join(appDir.path, 'databases', 'translation.db');

    if (!await File(oldDbPath).exists()) {
      AppLogger.i('No old translation database found', 'TagDatabaseMigration');
      return 0;
    }

    try {
      _ensureSqliteFfiInitialized();

      // 打开旧数据库
      final oldDb = await openDatabase(oldDbPath, readOnly: true);

      try {
        // 检查表是否存在
        final tables = await oldDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='translations'",
        );
        if (tables.isEmpty) {
          AppLogger.i('No translations table in old database', 'TagDatabaseMigration');
          return 0;
        }

        // 读取所有翻译数据
        final rows = await oldDb.query('translations');
        if (rows.isEmpty) {
          return 0;
        }

        // 转换为新格式
        final records = <TranslationRecord>[];
        for (final row in rows) {
          final tag = row['tag'] as String?;
          final translation = row['translation'] as String?;

          if (tag != null &&
              translation != null &&
              tag.isNotEmpty &&
              translation.isNotEmpty) {
            records.add(TranslationRecord(
              enTag: tag,
              zhTranslation: translation,
              source: 'hf_translation',
            ),);
          }
        }

        // 批量插入到统一数据库
        if (records.isNotEmpty) {
          await _unifiedDb.insertTranslations(records);
        }

        return records.length;
      } finally {
        await oldDb.close();
      }
    } catch (e, stack) {
      AppLogger.e('Failed to migrate translations', e, stack, 'TagDatabaseMigration');
      return 0;
    }
  }

  /// 迁移 Danbooru 标签
  Future<int> _migrateDanbooruTags() async {
    final appDir = await getApplicationSupportDirectory();
    final oldDbPath = path.join(appDir.path, 'databases', 'danbooru_tags.db');

    if (!await File(oldDbPath).exists()) {
      AppLogger.i('No old Danbooru tags database found', 'TagDatabaseMigration');
      return 0;
    }

    try {
      _ensureSqliteFfiInitialized();

      // 打开旧数据库
      final oldDb = await openDatabase(oldDbPath, readOnly: true);

      try {
        // 检查表是否存在
        final tables = await oldDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='tags'",
        );
        if (tables.isEmpty) {
          AppLogger.i('No tags table in old database', 'TagDatabaseMigration');
          return 0;
        }

        // 读取所有标签数据
        final rows = await oldDb.query('tags');
        if (rows.isEmpty) {
          return 0;
        }

        // 转换为新格式
        final records = <DanbooruTagRecord>[];
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        for (final row in rows) {
          final tag = row['tag'] as String?;
          final category = row['category'] as int? ?? 0;
          final count = row['count'] as int? ?? 0;

          if (tag != null && tag.isNotEmpty) {
            records.add(DanbooruTagRecord(
              tag: tag,
              category: category,
              postCount: count,
              lastUpdated: now,
            ),);
          }
        }

        // 批量插入到统一数据库
        if (records.isNotEmpty) {
          await _unifiedDb.insertDanbooruTags(records);
        }

        return records.length;
      } finally {
        await oldDb.close();
      }
    } catch (e, stack) {
      AppLogger.e('Failed to migrate Danbooru tags', e, stack, 'TagDatabaseMigration');
      return 0;
    }
  }

  /// 迁移共现数据
  Future<int> _migrateCooccurrences() async {
    final appDir = await getApplicationSupportDirectory();
    final oldDbPath = path.join(appDir.path, 'databases', 'cooccurrence.db');

    // 优先从旧数据库迁移
    if (await File(oldDbPath).exists()) {
      return await _migrateCooccurrencesFromDb(oldDbPath);
    }

    // 如果没有数据库，尝试从 CSV 迁移
    final csvPath = '${appDir.path}/tag_cache/danbooru_tags_cooccurrence.csv';
    if (await File(csvPath).exists()) {
      return await _migrateCooccurrencesFromCsv(csvPath);
    }

    AppLogger.i('No old cooccurrence data found', 'TagDatabaseMigration');
    return 0;
  }

  /// 从旧数据库迁移共现数据
  Future<int> _migrateCooccurrencesFromDb(String dbPath) async {
    try {
      _ensureSqliteFfiInitialized();

      final oldDb = await openDatabase(dbPath, readOnly: true);

      try {
        // 检查表是否存在
        final tables = await oldDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cooccurrence'",
        );
        if (tables.isEmpty) {
          return 0;
        }

        // 分批读取数据以避免内存问题
        const batchSize = 10000;
        var offset = 0;
        var totalMigrated = 0;

        while (true) {
          final rows = await oldDb.query(
            'cooccurrence',
            limit: batchSize,
            offset: offset,
          );

          if (rows.isEmpty) break;

          // 转换为新格式
          final records = <CooccurrenceRecord>[];
          for (final row in rows) {
            final tag1 = row['tag1'] as String?;
            final tag2 = row['tag2'] as String?;
            final count = row['count'] as int? ?? 0;

            if (tag1 != null &&
                tag2 != null &&
                tag1.isNotEmpty &&
                tag2.isNotEmpty &&
                count > 0) {
              records.add(CooccurrenceRecord(
                tag1: tag1,
                tag2: tag2,
                count: count,
                cooccurrenceScore: 0.0, // 旧数据没有共现分数
              ),);
            }
          }

          // 批量插入
          if (records.isNotEmpty) {
            await _unifiedDb.insertCooccurrences(records);
            totalMigrated += records.length;
          }

          if (rows.length < batchSize) break;
          offset += batchSize;

          // 报告进度
          onProgress?.call(
            'cooccurrences',
            0.5 + (offset / (offset + rows.length)) * 0.3,
            '迁移共现数据... $totalMigrated',
          );
        }

        return totalMigrated;
      } finally {
        await oldDb.close();
      }
    } catch (e, stack) {
      AppLogger.e('Failed to migrate cooccurrences from DB', e, stack, 'TagDatabaseMigration');
      return 0;
    }
  }

  /// 从 CSV 迁移共现数据（在 Isolate 中执行）
  Future<int> _migrateCooccurrencesFromCsv(String csvPath) async {
    try {
      // 在 Isolate 中解析 CSV
      final result = await Isolate.run(() async {
        final file = File(csvPath);
        if (!await file.exists()) return <CooccurrenceRecord>[];

        final content = await file.readAsString();
        final lines = content.split('\n');
        final records = <CooccurrenceRecord>[];

        // 跳过标题行
        final startIndex =
            lines.isNotEmpty && lines[0].contains(',') ? 1 : 0;

        for (var i = startIndex; i < lines.length; i++) {
          var line = lines[i].trim();
          if (line.isEmpty) continue;

          // 移除可能的引号包裹
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
              ),);
            }
          }
        }

        return records;
      });

      // 分批插入
      if (result.isNotEmpty) {
        const batchSize = 5000;
        for (var i = 0; i < result.length; i += batchSize) {
          final end = (i + batchSize < result.length) ? i + batchSize : result.length;
          final batch = result.sublist(i, end);
          await _unifiedDb.insertCooccurrences(batch);

          // 报告进度
          onProgress?.call(
            'cooccurrences',
            0.5 + (end / result.length) * 0.3,
            '迁移共现数据... $end / ${result.length}',
          );
        }
      }

      return result.length;
    } catch (e, stack) {
      AppLogger.e('Failed to migrate cooccurrences from CSV', e, stack, 'TagDatabaseMigration');
      return 0;
    }
  }

  /// 验证迁移结果
  Future<bool> _verifyMigration(Map<String, int> expectedCounts) async {
    try {
      final counts = await _unifiedDb.getRecordCounts();

      // 检查各表记录数是否合理
      // 注意：共现表是双向存储，所以记录数可能是预期的两倍
      final translationsOk = counts.translations >= (expectedCounts['translations'] ?? 0);
      final danbooruTagsOk = counts.danbooruTags >= (expectedCounts['danbooru_tags'] ?? 0);
      final cooccurrencesOk = counts.cooccurrences >= (expectedCounts['cooccurrences'] ?? 0);

      AppLogger.i(
        'Migration verification: translations=$translationsOk, '
        'danbooru_tags=$danbooruTagsOk, cooccurrences=$cooccurrencesOk',
        'TagDatabaseMigration',
      );

      return translationsOk && danbooruTagsOk && cooccurrencesOk;
    } catch (e, stack) {
      AppLogger.e('Migration verification failed', e, stack, 'TagDatabaseMigration');
      return false;
    }
  }

  /// 清理旧数据
  ///
  /// 注意：此方法在完全迁移后调用，目前保留以备将来使用
  // ignore: unused_element
  Future<void> _cleanupOldData() async {
    try {
      final appDir = await getApplicationSupportDirectory();

      // 删除旧数据库文件
      final oldDatabases = [
        path.join(appDir.path, 'databases', 'translation.db'),
        path.join(appDir.path, 'databases', 'danbooru_tags.db'),
        path.join(appDir.path, 'databases', 'cooccurrence.db'),
      ];

      for (final dbPath in oldDatabases) {
        try {
          final file = File(dbPath);
          if (await file.exists()) {
            await file.delete();
            AppLogger.i('Deleted old database: $dbPath', 'TagDatabaseMigration');
          }
        } catch (e) {
          AppLogger.w('Failed to delete old database: $dbPath', 'TagDatabaseMigration');
        }
      }

      // 删除旧 CSV 缓存（保留，因为 CooccurrenceService 可能还在使用）
      // 当 CooccurrenceService 完全迁移后再删除

      AppLogger.i('Old data cleanup completed', 'TagDatabaseMigration');
    } catch (e, stack) {
      AppLogger.e('Failed to cleanup old data', e, stack, 'TagDatabaseMigration');
    }
  }

  /// 重置迁移状态（用于测试或强制重新迁移）
  Future<void> resetMigrationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationVersionKey);
    AppLogger.i('Migration state reset', 'TagDatabaseMigration');
  }
}

/// 迁移结果
class MigrationResult {
  final bool success;
  final int totalMigrated;
  final Map<String, int> details;
  final String? error;
  final Duration? duration;

  const MigrationResult({
    required this.success,
    required this.totalMigrated,
    required this.details,
    this.error,
    this.duration,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('MigrationResult {');
    buffer.writeln('  success: $success,');
    buffer.writeln('  totalMigrated: $totalMigrated,');
    if (duration != null) {
      buffer.writeln('  duration: ${duration!.inMilliseconds}ms,');
    }
    if (error != null) {
      buffer.writeln('  error: $error,');
    }
    buffer.writeln('  details: $details');
    buffer.write('}');
    return buffer.toString();
  }
}
