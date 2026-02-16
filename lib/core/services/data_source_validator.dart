import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
