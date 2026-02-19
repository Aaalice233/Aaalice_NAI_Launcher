import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'connection_lease.dart';
import 'connection_pool_holder.dart';

/// 连接租借扩展
/// 
/// 为现有的 DataSource 提供简单的租借集成
extension ConnectionLeaseExtension on Database {
  /// 检查连接是否仍然有效
  Future<bool> get isHealthy async {
    try {
      await rawQuery('SELECT 1');
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// 数据源基础扩展
/// 
/// 提供统一的数据库操作模式
abstract class LeaseBasedDataSource {
  String get name;

  /// 使用租借执行操作
  /// 
  /// 这是推荐的操作模式，自动处理：
  /// - 连接获取
  /// - 健康检查
  /// - 版本检测
  /// - 自动重试
  /// - 连接释放
  Future<T> withLease<T>(
    String operationName,
    Future<T> Function(Database db) operation, {
    Duration? timeout,
    int maxRetries = 3,
  }) async {
    var attempt = 0;
    final operationId = '$name.$operationName#${DateTime.now().millisecondsSinceEpoch}';

    while (attempt < maxRetries) {
      ConnectionLease? lease;

      try {
        // 获取连接租借
        lease = await acquireLease(
          operationId: operationId,
          timeout: const Duration(seconds: 5),
        );

        // 执行操作
        final result = await lease.execute(operation).timeout(
          timeout ?? const Duration(seconds: 30),
        );

        return result;
      } on ConnectionVersionMismatchException {
        attempt++;
        AppLogger.w(
          '[$operationId] Version mismatch, retrying ($attempt/$maxRetries)',
          name,
        );
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      } on ConnectionInvalidException {
        attempt++;
        AppLogger.w(
          '[$operationId] Connection invalid, retrying ($attempt/$maxRetries)',
          name,
        );
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('database_closed') ||
            errorStr.contains('databaseexception')) {
          attempt++;
          AppLogger.w(
            '[$operationId] Database closed, retrying ($attempt/$maxRetries)',
            name,
          );
          await Future.delayed(Duration(milliseconds: 200 * attempt));
        } else {
          rethrow;
        }
      } finally {
        // 确保释放连接
        if (lease != null) {
          await lease.dispose();
        }
      }
    }

    throw StateError(
      '[$operationId] Failed after $maxRetries attempts',
    );
  }

  /// 批量执行操作
  /// 
  /// 每批操作使用独立的连接，避免长时间持有连接
  Stream<T> withLeaseBatch<T>(
    String operationName,
    List<Future<T> Function(Database db)> operations, {
    int batchSize = 10,
    Duration betweenBatches = const Duration(milliseconds: 10),
  }) async* {
    final batches = _chunk(operations, batchSize);
    var batchIndex = 0;

    for (final batch in batches) {
      final lease = await acquireLease(
        operationId: '$name.$operationName.batch#$batchIndex',
      );

      try {
        // 验证连接
        if (!await lease.validate()) {
          throw ConnectionInvalidException(
            operationId: '$name.$operationName.batch#$batchIndex',
          );
        }

        // 执行批次内所有操作
        for (final operation in batch) {
          yield await lease.execute(operation, validateBefore: false);
        }
      } finally {
        await lease.dispose();
      }

      // 批次间让出时间片
      if (betweenBatches > Duration.zero) {
        await Future.delayed(betweenBatches);
      }

      batchIndex++;
    }
  }

  /// 辅助方法：分批
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

/// 简化版租借获取（兼容现有代码）
/// 
/// 用于逐步迁移现有代码
class SimpleLeaseHelper {
  final String dataSourceName;

  SimpleLeaseHelper(this.dataSourceName);

  /// 执行数据库操作，带完整防护
  Future<T> execute<T>(
    String operationName,
    Future<T> Function(Database db) operation, {
    Duration? timeout,
    int maxRetries = 3,
  }) async {
    var attempt = 0;
    final operationId = '$dataSourceName.$operationName#${DateTime.now().millisecondsSinceEpoch}';

    while (attempt < maxRetries) {
      ConnectionLease? lease;

      try {
        // 等待连接池就绪
        var waitCount = 0;
        while (!ConnectionPoolHolder.isInitialized && waitCount < 50) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitCount++;
        }

        if (!ConnectionPoolHolder.isInitialized) {
          throw StateError('Connection pool not initialized after 5s');
        }

        // 获取连接租借
        lease = await acquireLease(
          operationId: operationId,
          timeout: const Duration(seconds: 5),
        );

        // 执行操作
        final result = await lease.execute(
          (db) => operation(db),
          validateBefore: true,
        ).timeout(timeout ?? const Duration(seconds: 30));

        return result;
      } on ConnectionVersionMismatchException {
        attempt++;
        AppLogger.w(
          '[$operationId] Version mismatch, retrying ($attempt/$maxRetries)',
          dataSourceName,
        );
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      } on ConnectionInvalidException {
        attempt++;
        AppLogger.w(
          '[$operationId] Connection invalid, retrying ($attempt/$maxRetries)',
          dataSourceName,
        );
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('database_closed') ||
            errorStr.contains('databaseexception') ||
            errorStr.contains('bad state')) {
          attempt++;
          AppLogger.w(
            '[$operationId] Database error, retrying ($attempt/$maxRetries): $e',
            dataSourceName,
          );
          await Future.delayed(Duration(milliseconds: 200 * attempt));
        } else {
          rethrow;
        }
      } finally {
        if (lease != null) {
          await lease.dispose();
        }
      }
    }

    throw StateError(
      '[$operationId] Operation failed after $maxRetries attempts',
    );
  }

  /// 流式批量执行
  Stream<T> executeBatch<T>(
    String operationName,
    List<T> items,
    Future<T> Function(Database db, T item) processor, {
    int batchSize = 50,
  }) async* {
    final chunks = _chunk(items, batchSize);
    var chunkIndex = 0;

    for (final chunk in chunks) {
      final lease = await acquireLease(
        operationId: '$dataSourceName.$operationName.chunk#$chunkIndex',
      );

      try {
        // 验证连接
        if (!await lease.validate()) {
          throw ConnectionInvalidException(
            operationId: '$dataSourceName.$operationName.chunk#$chunkIndex',
          );
        }

        // 执行批次内所有操作
        for (final item in chunk) {
          yield await lease.execute(
            (db) => processor(db, item),
            validateBefore: false,
          );
        }
      } finally {
        await lease.dispose();
      }

      // 让出时间片
      await Future.delayed(const Duration(milliseconds: 10));
      chunkIndex++;
    }
  }

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
