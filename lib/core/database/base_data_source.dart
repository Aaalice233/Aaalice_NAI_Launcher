import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'connection_lease.dart';
import 'connection_pool_holder.dart';
import 'data_source.dart' as ds;
import 'database_error_summary.dart';

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
  String toString() => 'DataSourceOperationException: $message (operation: $operationName)';
}

class DatabaseOperation<T> {
  final String name;
  final Future<T> Function(Database db) executor;

  const DatabaseOperation({required this.name, required this.executor});
}

abstract class EnhancedBaseDataSource extends ds.BaseDataSource {
  // 默认超时配置
  static const Duration _defaultOperationTimeout = Duration(seconds: 30);
  static const Duration _defaultAcquireTimeout = Duration(seconds: 5);
  static const int _defaultMaxRetries = 3;
  static const int _defaultBatchSize = 50;

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
    final stopwatch = Stopwatch()..start();

    while (attempt < effectiveMaxRetries) {
      ConnectionLease? lease;

      try {
        lease = await _acquireLease(operationId: operationId);

        final result = await lease
            .execute(operation, validateBefore: true, autoRetry: false)
            .timeout(effectiveTimeout);

        stopwatch.stop();
        _logOperationDuration(operationId, stopwatch.elapsedMilliseconds);

        return result;
      } on ConnectionVersionMismatchException catch (e) {
        attempt++;
        _logRetry(operationId, attempt, effectiveMaxRetries, 'version mismatch', e);
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      } on ConnectionInvalidException catch (e) {
        attempt++;
        _logRetry(operationId, attempt, effectiveMaxRetries, 'connection invalid', e);
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      } on TimeoutException catch (e) {
        attempt++;
        _logRetry(operationId, attempt, effectiveMaxRetries, 'timeout', e);
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      } catch (e) {
        if (_isRetryableError(e) && attempt < effectiveMaxRetries - 1) {
          attempt++;
          _logRetry(operationId, attempt, effectiveMaxRetries, 'database error', e);
          final isDbClosed = e.toString().toLowerCase().contains('database has already been closed');
          final delayMs = isDbClosed ? 500 * attempt : 200 * attempt;
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          throw DataSourceOperationException(
            message: 'Operation failed: ${databaseErrorSummary(e)}',
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

  Stream<T> executeBatch<T>(
    List<DatabaseOperation<T>> operations, {
    int batchSize = _defaultBatchSize,
  }) async* {
    if (operations.isEmpty) return;

    final batches = chunk(operations, batchSize);
    var batchIndex = 0;

    for (final batch in batches) {
      final operationId = _generateOperationId('batch#$batchIndex');
      ConnectionLease? lease;

      try {
        lease = await _acquireLease(operationId: operationId);

        if (!await lease.validate()) {
          throw ConnectionInvalidException(operationId: operationId);
        }

        for (final op in batch) {
          final result = await lease.execute(op.executor, validateBefore: false);
          yield result;
        }
      } catch (e, stack) {
        AppLogger.e('Batch operation failed at batch $batchIndex', e, stack, name);
        rethrow;
      } finally {
        await lease?.dispose();
      }

      await Future.delayed(const Duration(milliseconds: 10));
      batchIndex++;
    }
  }

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
        AppLogger.e('Query stream failed at offset $offset', e, stack, name);
        rethrow;
      } finally {
        await lease?.dispose();
      }

      if (hasMore) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }
  }

  Future<ConnectionLease> _acquireLease({String? operationId}) async {
    final id = operationId ?? '${name}_${DateTime.now().millisecondsSinceEpoch}';

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

    return acquireLease(operationId: id, timeout: _defaultAcquireTimeout);
  }

  /// 生成功能ID
  String _generateOperationId(String operationName) {
    return '$name.$operationName#${DateTime.now().millisecondsSinceEpoch}';
  }

  bool _isRetryableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('database_closed') ||
        errorStr.contains('database has already been closed') ||
        errorStr.contains('not initialized') ||
        errorStr.contains('connection invalid') ||
        errorStr.contains('databaseexception') ||
        errorStr.contains('bad state');
  }

  void _logRetry(String operationId, int attempt, int maxRetries, String reason, dynamic error) {
    AppLogger.w(
      '[$operationId] $reason, retrying ($attempt/$maxRetries): '
      '${databaseErrorSummary(error)}',
      name,
    );
  }

  void _logOperationDuration(String operationId, int durationMs) {
    // 【优化】只在慢操作时记录，减少日志量
    if (durationMs > 1000) {
      AppLogger.w('Slow operation: $operationId took ${durationMs}ms', 'DataSource');
    }
    // 正常操作不记录，避免日志刷屏
  }

  List<List<T>> chunk<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, (i + chunkSize).clamp(0, list.length)));
    }
    return chunks;
  }
}
