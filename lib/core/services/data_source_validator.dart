import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/database_manager.dart';
import '../utils/app_logger.dart';

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
class DataSourceValidator {
  static const _configs = [
    ('danbooru_tags', 10000),
    ('translations', 1000),
    ('cooccurrences', 1000),
  ];

  /// 验证所有数据源
  Future<DataSourceStatus> validateAll() async {
    final manager = DatabaseManager.instance;

    if (!manager.isInitialized) {
      AppLogger.w('Database not initialized, cannot validate', 'DataSourceValidator');
      return const DataSourceStatus(
        danbooruTags: false,
        translations: false,
        cooccurrences: false,
      );
    }

    Database? db;
    try {
      db = await manager.acquireDatabase();
    final results = await Future.wait([
      _validateTable(db, _configs[0]),
      _validateTable(db, _configs[1]),
      _validateTable(db, _configs[2]),
    ]);

    // 释放数据库连接
    await manager.releaseDatabase(db);

    return DataSourceStatus(
      danbooruTags: results[0].$1,
      translations: results[1].$1,
      cooccurrences: results[2].$1,
      danbooruTagCount: results[0].$2,
      translationCount: results[1].$2,
      cooccurrenceCount: results[2].$2,
    );
    } catch (e) {
      AppLogger.e('Failed to validate data sources', e, null, 'DataSourceValidator');
      if (db != null) {
        await manager.releaseDatabase(db);
      }
      return const DataSourceStatus(
        danbooruTags: false,
        translations: false,
        cooccurrences: false,
      );
    }
  }

  Future<(bool, int)> _validateTable(Database db, (String, int) config) async {
    final (tableName, minCount) = config;
    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
      final count = result.first['count'] as int? ?? 0;
      final isValid = count >= minCount;
      AppLogger.i('$tableName count: $count (valid: $isValid)', 'DataSourceValidator');
      return (isValid, count);
    } catch (e) {
      AppLogger.w('Failed to validate $tableName: $e', 'DataSourceValidator');
      return (false, 0);
    }
  }
}
