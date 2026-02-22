import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'connection_lease.dart';
import 'connection_pool_holder.dart';
import 'data_source.dart' as ds;

/// 数据库操作异常
class DataSourceOperationException implements Exception {
  final String message;
  final String operationName;
  final dynamic originalError;

  DataSourceOperationException({
    required this.message,
    required this.operationName,
    this.originalError,
  });

  @override
  String toString() =>
      'DataSourceOperationException: $message (operation: $operationName)';
}

/// 数据库操作定义
///
/// 用于批量执行时封装单个操作
class DatabaseOperation<T> {
  final String name;
  final Future<T> Function(Database db) executor;

  const DatabaseOperation({
    required this.name,
    required this.executor,
  });
}

/// BaseDataSource 抽象基类
///
/// 继承自 data_source.dart 的 BaseDataSource，
/// 提供基于 ConnectionLease 的标准化数据库操作方法：
/// - 连接生命周期管理
/// - 自动重试机制
/// - 超时控制
/// - 流式查询支持
/// - 事务支持
///
/// 为了避免命名冲突，这个类重命名自新的实现，
/// 原来的 data_source.dart 中的 BaseDataSource 作为基础生命周期管理保留。
abstract class EnhancedBaseDataSource extends ds.BaseDataSource {
  // 默认超时配置
  static const Duration _defaultOperationTimeout = Duration(seconds: 30);
  static const Duration _defaultTransactionTimeout = Duration(seconds: 60);
  static const Duration _defaultAcquireTimeout = Duration(seconds: 5);
  static const int _defaultMaxRetries = 3;
  static const int _defaultBatchSize = 50;

  /// 使用 ConnectionLease 执行单个操作
  ///
  /// [operationName] 操作名称（用于日志和诊断）
  /// [operation] 数据库操作函数
  /// [timeout] 操作超时时间（默认30秒）
  /// [maxRetries] 最大重试次数（默认3次）
  ///
  /// 自动处理：
  /// - 连接获取和释放
  /// - 版本检测和重试
  /// - 连接错误自动恢复
  Future<T> execute<T>(
    String operationName,
    Future<T> Function(Database db) operation, {
    Duration? timeout,
    int? maxRetries,
  }) async {
    final effectiveTimeout = timeout ?? _defaultOperationTimeout;
    final effectiveMaxRetries = maxRetries ?? _defaultMaxRetries;
    var attempt = 0;
    final operationId = _generateOperationId(operationName);

    while (attempt < effectiveMaxRetries) {
      ConnectionLease? lease;

      try {
        // 获取连接租借
        lease = await _acquireLease(operationId: operationId);

        // 执行操作
        final result = await lease
            .execute(
              operation,
              validateBefore: true,
              autoRetry: false,
            )
            .timeout(effectiveTimeout);

        // 检查使用时长
        _logLongUsage(lease, operationId);

        return result;
      } on ConnectionVersionMismatchException catch (e) {
        attempt++;
        _logRetry(
          operationId,
          attempt,
          effectiveMaxRetries,
          'version mismatch',
          e,
        );
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      } on ConnectionInvalidException catch (e) {
        attempt++;
        _logRetry(
          operationId,
          attempt,
          effectiveMaxRetries,
          'connection invalid',
          e,
        );
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      } on TimeoutException catch (e) {
        attempt++;
        _logRetry(
          operationId,
          attempt,
          effectiveMaxRetries,
          'timeout',
          e,
        );
        // 超时后等待更长时间
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      } catch (e) {
        if (_isRetryableError(e) && attempt < effectiveMaxRetries - 1) {
          attempt++;
          _logRetry(
            operationId,
            attempt,
            effectiveMaxRetries,
            'database error',
            e,
          );
          // 数据库关闭错误需要更长的恢复时间
          final isDbClosed = e.toString().toLowerCase().contains('database has already been closed');
          final delayMs = isDbClosed ? 500 * attempt : 200 * attempt;
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          throw DataSourceOperationException(
            message: 'Operation failed: $e',
            operationName: operationId,
            originalError: e,
          );
        }
      } finally {
        await lease?.dispose();
      }
    }

    throw DataSourceOperationException(
      message: 'Failed after $effectiveMaxRetries attempts',
      operationName: operationId,
    );
  }

  /// 批量执行操作
  ///
  /// [operations] 操作列表
  /// [batchSize] 每批处理数量（默认50）
  ///
  /// 特点：
  /// - 每批使用独立连接
  /// - 批次间让出时间片
  /// - 流式返回结果
  Stream<T> executeBatch<T>(
    List<DatabaseOperation<T>> operations, {
    int batchSize = _defaultBatchSize,
  }) async* {
    if (operations.isEmpty) return;

    final batches = _chunk(operations, batchSize);
    var batchIndex = 0;

    for (final batch in batches) {
      final operationId = _generateOperationId('batch#$batchIndex');
      ConnectionLease? lease;

      try {
        // 获取新的连接租借
        lease = await _acquireLease(operationId: operationId);

        // 验证连接
        if (!await lease.validate()) {
          throw ConnectionInvalidException(operationId: operationId);
        }

        // 执行批次内所有操作
        for (final op in batch) {
          final result = await lease.execute(
            op.executor,
            validateBefore: false,
          );
          yield result;
        }
      } catch (e, stack) {
        AppLogger.e(
          'Batch operation failed at batch $batchIndex',
          e,
          stack,
          name,
        );
        rethrow;
      } finally {
        await lease?.dispose();
      }

      // 批次间让出时间片
      await Future.delayed(const Duration(milliseconds: 10));
      batchIndex++;
    }
  }

  /// 在事务中执行操作
  ///
  /// [operationName] 操作名称
  /// [operation] 事务操作函数
  /// [timeout] 事务超时时间（默认60秒）
  ///
  /// 注意：
  /// - 事务内操作使用同一个连接
  /// - 事务期间连接不会被其他操作使用
  Future<T> executeTransaction<T>(
    String operationName,
    Future<T> Function(Transaction txn) operation, {
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _defaultTransactionTimeout;

    return execute(
      '$operationName.txn',
      (db) async {
        return db.transaction((txn) async {
          return operation(txn);
        });
      },
      timeout: effectiveTimeout,
    );
  }

  /// 流式查询（用于大数据集）
  ///
  /// [sql] SQL 查询语句
  /// [args] 查询参数
  /// [batchSize] 每批获取数量（默认50）
  ///
  /// 特点：
  /// - 分批获取数据，避免内存溢出
  /// - 每批使用独立连接
  /// - 支持中断和恢复
  Stream<Map<String, dynamic>> executeQueryStream(
    String sql,
    List<dynamic>? args, {
    int batchSize = _defaultBatchSize,
  }) async* {
    var offset = 0;
    var hasMore = true;

    while (hasMore) {
      final operationId = _generateOperationId('queryStream#$offset');
      ConnectionLease? lease;

      try {
        lease = await _acquireLease(operationId: operationId);

        // 构建分页查询
        final paginatedSql = '$sql LIMIT ? OFFSET ?';
        final paginatedArgs = [...?args, batchSize, offset];

        final results = await lease.execute(
          (db) async => db.rawQuery(paginatedSql, paginatedArgs),
          validateBefore: true,
        );

        if (results.isEmpty) {
          hasMore = false;
        } else {
          for (final row in results) {
            yield row;
          }
          offset += results.length;
          hasMore = results.length >= batchSize;
        }
      } catch (e, stack) {
        AppLogger.e(
          'Query stream failed at offset $offset',
          e,
          stack,
          name,
        );
        rethrow;
      } finally {
        await lease?.dispose();
      }

      // 批次间让出时间片
      if (hasMore) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }
  }

  /// 获取连接租借
  ///
  /// 内部方法，用于获取 ConnectionLease
  Future<ConnectionLease> _acquireLease({String? operationId}) async {
    final id =
        operationId ?? '${name}_${DateTime.now().millisecondsSinceEpoch}';

    // 等待连接池就绪
    var waitCount = 0;
    while (!ConnectionPoolHolder.isInitialized && waitCount < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    if (!ConnectionPoolHolder.isInitialized) {
      throw DataSourceOperationException(
        message: 'Connection pool not initialized after 5s',
        operationName: id,
      );
    }

    return acquireLease(
      operationId: id,
      timeout: _defaultAcquireTimeout,
    );
  }

  /// 生成功能ID
  String _generateOperationId(String operationName) {
    return '$name.$operationName#${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 检查错误是否可重试
  bool _isRetryableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('database_closed') ||
        errorStr.contains('database has already been closed') ||
        errorStr.contains('not initialized') ||
        errorStr.contains('connection invalid') ||
        errorStr.contains('databaseexception') ||
        errorStr.contains('bad state');
  }

  /// 记录重试日志
  void _logRetry(
    String operationId,
    int attempt,
    int maxRetries,
    String reason,
    dynamic error,
  ) {
    AppLogger.w(
      '[$operationId] $reason, retrying ($attempt/$maxRetries): $error',
      name,
    );
  }

  /// 记录长时间使用警告
  void _logLongUsage(ConnectionLease lease, String operationId) {
    if (lease.usageTime > const Duration(seconds: 5)) {
      AppLogger.w(
        'Long running operation detected: ${lease.usageTime.inSeconds}s for $operationId',
        name,
      );
    }
  }

  /// 分批辅助方法
  List<List<T>> _chunk<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
          i,
          i + chunkSize > list.length ? list.length : i + chunkSize,
        ),
      );
    }
    return chunks;
  }
}
