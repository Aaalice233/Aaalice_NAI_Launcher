import 'dart:async';

import '../utils/app_logger.dart';
import 'connection_pool_holder.dart';
import 'data_source.dart';

/// 健康检查详情
class HealthCheckResult {
  final HealthStatus status;
  final String message;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  const HealthCheckResult({
    required this.status,
    required this.message,
    this.details = const {},
    required this.timestamp,
  });

  bool get isHealthy => status == HealthStatus.healthy;
  bool get isCorrupted => status == HealthStatus.corrupted;
}

/// 数据库健康检查器
///
/// 提供三层健康检查机制：
/// 1. 快速检查 (quickCheck): 检查表是否存在，<100ms
/// 2. 完整检查 (fullCheck): PRAGMA integrity_check，无超时限制，必须完成
/// 3. 数据验证 (validateData): 样本数据验证
class HealthChecker {
  HealthChecker._();

  static final HealthChecker _instance = HealthChecker._();

  /// 获取单例实例
  static HealthChecker get instance => _instance;

  static const List<String> _requiredTables = [
    'images',
    'metadata',
    'favorites',
    'tags',
    'image_tags',
    'folders',
    'scan_history',
    'metadata_fts',
    'db_metadata',
  ];

  DateTime? _lastQuickCheck;
  DateTime? _lastFullCheck;
  HealthCheckResult? _lastResult;

  /// 获取上次快速检查时间
  DateTime? get lastQuickCheck => _lastQuickCheck;

  /// 获取上次完整检查时间
  DateTime? get lastFullCheck => _lastFullCheck;

  /// 获取上次检查结果
  HealthCheckResult? get lastResult => _lastResult;

  /// 快速健康检查
  ///
  /// 检查内容：
  /// - 数据库连接是否可用
  /// - 必需表是否存在
  /// - 超时时间：<100ms
  ///
  /// 返回：健康检查结果
  Future<HealthCheckResult> quickCheck() async {
    final stopwatch = Stopwatch()..start();
    final db = await ConnectionPoolHolder.instance.acquire();

    try {
      // 检查数据库是否可查询
      await db.rawQuery('SELECT 1');

      // 检查必需表是否存在
      final missingTables = <String>[];
      for (final table in _requiredTables) {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        if (result.isEmpty) {
          missingTables.add(table);
        }
      }

      stopwatch.stop();
      _lastQuickCheck = DateTime.now();

      if (missingTables.isNotEmpty) {
        final result = HealthCheckResult(
          status: HealthStatus.degraded,
          message: 'Missing required tables: ${missingTables.join(', ')}',
          details: {
            'missingTables': missingTables,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
          timestamp: DateTime.now(),
        );
        _lastResult = result;
        return result;
      }

      final result = HealthCheckResult(
        status: HealthStatus.healthy,
        message: 'Quick check passed',
        details: {
          'durationMs': stopwatch.elapsedMilliseconds,
          'tablesChecked': _requiredTables.length,
        },
        timestamp: DateTime.now(),
      );
      _lastResult = result;

      AppLogger.i(
        'Quick health check passed (${stopwatch.elapsedMilliseconds}ms)',
        'HealthChecker',
      );
      return result;
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.e('Quick health check failed', e, stack, 'HealthChecker');

      final result = HealthCheckResult(
        status: HealthStatus.corrupted,
        message: 'Quick check failed: $e',
        details: {
          'error': e.toString(),
          'durationMs': stopwatch.elapsedMilliseconds,
        },
        timestamp: DateTime.now(),
      );
      _lastResult = result;
      return result;
    } finally {
      await ConnectionPoolHolder.instance.release(db);
    }
  }

  /// 完整健康检查
  ///
  /// 检查内容：
  /// - PRAGMA integrity_check
  /// - PRAGMA foreign_key_check
  /// - 索引完整性检查
  /// - 无超时限制，必须完成
  ///
  /// 返回：健康检查结果
  Future<HealthCheckResult> fullCheck() async {
    final stopwatch = Stopwatch()..start();
    final db = await ConnectionPoolHolder.instance.acquire();

    try {
      // PRAGMA integrity_check - 无超时限制
      final integrityResult = await db.rawQuery('PRAGMA integrity_check');
      final integrityStatus = integrityResult.first['integrity_check'] as String;

      if (integrityStatus != 'ok') {
        stopwatch.stop();
        _lastFullCheck = DateTime.now();

        final result = HealthCheckResult(
          status: HealthStatus.corrupted,
          message: 'Integrity check failed: $integrityStatus',
          details: {
            'integrityCheck': integrityStatus,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
          timestamp: DateTime.now(),
        );
        _lastResult = result;

        AppLogger.e(
          'Full health check failed: $integrityStatus',
          null,
          null,
          'HealthChecker',
        );
        return result;
      }

      // PRAGMA foreign_key_check
      final fkResult = await db.rawQuery('PRAGMA foreign_key_check');
      final fkErrors = <Map<String, dynamic>>[];
      for (final row in fkResult) {
        fkErrors.add({
          'table': row['table'],
          'rowid': row['rowid'],
          'parent': row['parent'],
          'fkid': row['fkid'],
        });
      }

      // 检查索引完整性
      final indexResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND sql IS NULL",
      );
      final invalidIndexes = indexResult.map((r) => r['name'] as String).toList();

      stopwatch.stop();
      _lastFullCheck = DateTime.now();

      if (fkErrors.isNotEmpty || invalidIndexes.isNotEmpty) {
        final result = HealthCheckResult(
          status: HealthStatus.degraded,
          message: 'Database has inconsistencies',
          details: {
            'foreignKeyErrors': fkErrors,
            'invalidIndexes': invalidIndexes,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
          timestamp: DateTime.now(),
        );
        _lastResult = result;

        AppLogger.w(
          'Full health check found issues: FK errors=${fkErrors.length}, '
          'Invalid indexes=${invalidIndexes.length}',
          'HealthChecker',
        );
        return result;
      }

      final result = HealthCheckResult(
        status: HealthStatus.healthy,
        message: 'Full check passed',
        details: {
          'integrityCheck': 'ok',
          'foreignKeyCheck': 'ok',
          'indexCheck': 'ok',
          'durationMs': stopwatch.elapsedMilliseconds,
        },
        timestamp: DateTime.now(),
      );
      _lastResult = result;

      AppLogger.i(
        'Full health check passed (${stopwatch.elapsedMilliseconds}ms)',
        'HealthChecker',
      );
      return result;
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.e('Full health check failed', e, stack, 'HealthChecker');

      final result = HealthCheckResult(
        status: HealthStatus.corrupted,
        message: 'Full check failed: $e',
        details: {
          'error': e.toString(),
          'durationMs': stopwatch.elapsedMilliseconds,
        },
        timestamp: DateTime.now(),
      );
      _lastResult = result;
      return result;
    } finally {
      await ConnectionPoolHolder.instance.release(db);
    }
  }

  /// 数据验证检查
  ///
  /// 检查内容：
  /// - 样本数据可读性
  /// - 关键数据完整性
  /// - 数据格式验证
  ///
  /// 返回：健康检查结果
  Future<HealthCheckResult> validateData() async {
    final stopwatch = Stopwatch()..start();
    final db = await ConnectionPoolHolder.instance.acquire();

    try {
      final validationErrors = <String>[];
      final sampleStats = <String, dynamic>{};

      // 验证图片表样本数据
      try {
        final imageCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM images WHERE is_deleted = 0',
        );
        sampleStats['totalImages'] = imageCount.first['count'];

        // 随机抽样检查
        final sample = await db.rawQuery(
          'SELECT id, file_path, file_name FROM images WHERE is_deleted = 0 LIMIT 5',
        );
        sampleStats['sampleImages'] = sample.length;

        for (final row in sample) {
          if (row['file_path'] == null || (row['file_path'] as String).isEmpty) {
            validationErrors.add('Image ${row['id']} has empty file_path');
          }
        }
      } catch (e) {
        validationErrors.add('Failed to validate images: $e');
      }

      // 验证元数据表关联完整性
      try {
        final orphanedMetadata = await db.rawQuery(
          '''
          SELECT COUNT(*) as count 
          FROM metadata m 
          LEFT JOIN images i ON m.image_id = i.id 
          WHERE i.id IS NULL
          ''',
        );
        final orphanedCount = orphanedMetadata.first['count'] as int? ?? 0;
        sampleStats['orphanedMetadata'] = orphanedCount;

        if (orphanedCount > 0) {
          validationErrors.add('Found $orphanedCount orphaned metadata records');
        }
      } catch (e) {
        validationErrors.add('Failed to validate metadata: $e');
      }

      // 验证收藏记录完整性
      try {
        final orphanedFavorites = await db.rawQuery(
          '''
          SELECT COUNT(*) as count 
          FROM favorites f 
          LEFT JOIN images i ON f.image_id = i.id 
          WHERE i.id IS NULL OR i.is_deleted = 1
          ''',
        );
        final orphanedCount = orphanedFavorites.first['count'] as int? ?? 0;
        sampleStats['orphanedFavorites'] = orphanedCount;

        if (orphanedCount > 0) {
          validationErrors.add('Found $orphanedCount orphaned favorite records');
        }
      } catch (e) {
        validationErrors.add('Failed to validate favorites: $e');
      }

      // 验证 FTS5 虚拟表
      try {
        await db.rawQuery('SELECT COUNT(*) FROM metadata_fts');
        sampleStats['fts5Accessible'] = true;
      } catch (e) {
        validationErrors.add('FTS5 table not accessible: $e');
        sampleStats['fts5Accessible'] = false;
      }

      stopwatch.stop();

      if (validationErrors.isNotEmpty) {
        final result = HealthCheckResult(
          status: HealthStatus.degraded,
          message: 'Data validation found issues',
          details: {
            'validationErrors': validationErrors,
            'sampleStats': sampleStats,
            'durationMs': stopwatch.elapsedMilliseconds,
          },
          timestamp: DateTime.now(),
        );
        _lastResult = result;

        AppLogger.w(
          'Data validation found ${validationErrors.length} issues',
          'HealthChecker',
        );
        return result;
      }

      final result = HealthCheckResult(
        status: HealthStatus.healthy,
        message: 'Data validation passed',
        details: {
          'sampleStats': sampleStats,
          'durationMs': stopwatch.elapsedMilliseconds,
        },
        timestamp: DateTime.now(),
      );
      _lastResult = result;

      AppLogger.i(
        'Data validation passed (${stopwatch.elapsedMilliseconds}ms)',
        'HealthChecker',
      );
      return result;
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.e('Data validation failed', e, stack, 'HealthChecker');

      final result = HealthCheckResult(
        status: HealthStatus.corrupted,
        message: 'Data validation failed: $e',
        details: {
          'error': e.toString(),
          'durationMs': stopwatch.elapsedMilliseconds,
        },
        timestamp: DateTime.now(),
      );
      _lastResult = result;
      return result;
    } finally {
      await ConnectionPoolHolder.instance.release(db);
    }
  }

  /// 执行完整的三层健康检查
  ///
  /// 按顺序执行：quickCheck → fullCheck → validateData
  /// 如果快速检查失败，跳过后续检查
  ///
  /// 返回：最差的检查结果
  Future<HealthCheckResult> runAllChecks() async {
    // 1. 快速检查
    final quickResult = await quickCheck();
    if (!quickResult.isHealthy) {
      AppLogger.w('Quick check failed, skipping remaining checks', 'HealthChecker');
      return quickResult;
    }

    // 2. 完整检查
    final fullResult = await fullCheck();
    if (fullResult.isCorrupted) {
      return fullResult;
    }

    // 3. 数据验证
    final dataResult = await validateData();

    // 返回最差的结果
    if (dataResult.status.index > fullResult.status.index) {
      return dataResult;
    }
    return fullResult;
  }

  /// 重置检查器状态
  void reset() {
    _lastQuickCheck = null;
    _lastFullCheck = null;
    _lastResult = null;
    AppLogger.d('HealthChecker reset', 'HealthChecker');
  }
}
