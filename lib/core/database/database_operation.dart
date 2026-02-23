import 'dart:async';
import 'dart:math' as math;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';
import 'connection_lease.dart';

/// 数据库操作异常
class DatabaseOperationException implements Exception {
  final String message;
  final String? operationName;
  final dynamic originalError;
  final StackTrace? stackTrace;

  DatabaseOperationException(
    this.message, {
    this.operationName,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final parts = <String>['DatabaseOperationException: $message'];
    if (operationName != null) parts.add('(operation: $operationName)');
    if (originalError != null) parts.add('(original: $originalError)');
    return parts.join(' ');
  }
}

/// 操作超时异常
class DatabaseOperationTimeoutException extends DatabaseOperationException {
  final Duration timeout;

  DatabaseOperationTimeoutException({
    required this.timeout,
    required super.operationName,
  }) : super(
          'Operation timed out after ${timeout.inMilliseconds}ms',
        );
}

/// 操作重试耗尽异常
class DatabaseOperationRetriesExhaustedException
    extends DatabaseOperationException {
  final int maxRetries;

  DatabaseOperationRetriesExhaustedException({
    required this.maxRetries,
    required super.operationName,
    dynamic lastError,
  }) : super(
          'Operation failed after $maxRetries retries',
          originalError: lastError,
        );
}

/// 事务异常
class DatabaseTransactionException extends DatabaseOperationException {
  DatabaseTransactionException(
    super.message, {
    super.operationName,
    super.originalError,
    super.stackTrace,
  });
}

/// 数据库操作包装器
///
/// 提供以下功能：
/// 1. 使用 ConnectionLease 获取连接
/// 2. 操作超时控制
/// 3. 自动重试机制（指数退避）
/// 4. 慢操作检测
/// 5. 详细的日志记录
///
/// 示例：
/// ```dart
/// final operation = DatabaseOperation<List<Map>>(
///   name: 'getUserById',
///   executor: (db) => db.query('users', where: 'id = ?', whereArgs: [1]),
///   timeout: Duration(seconds: 10),
///   maxRetries: 3,
/// );
/// final users = await operation.execute();
/// ```
class DatabaseOperation<T> {
  /// 操作名称，用于日志和诊断
  final String name;

  /// 操作执行器
  final Future<T> Function(Database db) executor;

  /// 操作超时时间
  final Duration timeout;

  /// 最大重试次数
  final int maxRetries;

  /// 基础重试延迟
  final Duration retryDelay;

  /// 慢操作阈值（超过此时间触发回调）
  final Duration slowOperationThreshold;

  /// 慢操作回调
  final void Function(Duration duration)? onSlowOperation;

  /// 操作完成回调
  final void Function(T result, Duration duration)? onComplete;

  /// 操作失败回调
  final void Function(dynamic error, Duration duration)? onError;

  /// 创建数据库操作
  ///
  /// [name] 操作名称，用于日志和诊断
  /// [executor] 实际的数据库操作函数
  /// [timeout] 操作超时时间，默认 30 秒
  /// [maxRetries] 最大重试次数，默认 3
  /// [retryDelay] 基础重试延迟，默认 200 毫秒
  /// [slowOperationThreshold] 慢操作阈值，默认 1 秒
  /// [onSlowOperation] 慢操作回调
  /// [onComplete] 操作完成回调
  /// [onError] 操作失败回调
  DatabaseOperation({
    required this.name,
    required this.executor,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 200),
    this.slowOperationThreshold = const Duration(seconds: 1),
    this.onSlowOperation,
    this.onComplete,
    this.onError,
  });

  /// 执行数据库操作
  ///
  /// 执行流程：
  /// 1. 获取连接租借
  /// 2. 执行操作（带重试机制）
  /// 3. 监控执行时间
  /// 4. 释放连接
  /// 5. 触发回调
  ///
  /// 返回操作结果
  /// 抛出 [DatabaseOperationException] 及其子类
  Future<T> execute() async {
    final stopwatch = Stopwatch()..start();
    final operationId = '$name#${DateTime.now().millisecondsSinceEpoch}';

    AppLogger.d('Starting operation: $operationId', 'DatabaseOperation');

    try {
      final result = await _executeWithRetry(operationId);

      stopwatch.stop();
      final duration = stopwatch.elapsed;

      // 检查是否慢操作
      if (duration > slowOperationThreshold) {
        AppLogger.w(
          'Slow operation detected: $operationId took ${duration.inMilliseconds}ms',
          'DatabaseOperation',
        );
        onSlowOperation?.call(duration);
      }

      AppLogger.d(
        'Operation completed: $operationId in ${duration.inMilliseconds}ms',
        'DatabaseOperation',
      );

      onComplete?.call(result, duration);
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      final duration = stopwatch.elapsed;

      AppLogger.e(
        'Operation failed: $operationId after ${duration.inMilliseconds}ms',
        e,
        stackTrace,
        'DatabaseOperation',
      );

      onError?.call(e, duration);

      if (e is DatabaseOperationException) {
        rethrow;
      }

      throw DatabaseOperationException(
        'Operation failed',
        operationName: name,
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 带重试的执行逻辑
  Future<T> _executeWithRetry(String operationId) async {
    var attempt = 0;

    while (attempt <= maxRetries) {
      ConnectionLease? lease;

      try {
        // 获取连接租借
        lease = await acquireLease(
          operationId: operationId,
          timeout: const Duration(seconds: 5),
        );

        AppLogger.d(
          '[$operationId] Attempt ${attempt + 1}/${maxRetries + 1}',
          'DatabaseOperation',
        );

        // 执行操作（带超时）
        final result = await lease
            .execute(executor)
            .timeout(timeout);

        // 如果成功，返回结果
        await lease.dispose();
        return result;
      } on ConnectionVersionMismatchException catch (e) {
        await lease?.dispose();
        attempt++;

        if (attempt > maxRetries) {
          throw DatabaseOperationRetriesExhaustedException(
            maxRetries: maxRetries,
            operationName: name,
            lastError: e,
          );
        }

        final delay = _calculateRetryDelay(attempt);
        AppLogger.w(
          '[$operationId] Version mismatch, retrying in ${delay.inMilliseconds}ms ($attempt/$maxRetries)',
          'DatabaseOperation',
        );
        await Future.delayed(delay);
      } on ConnectionInvalidException catch (e) {
        await lease?.dispose();
        attempt++;

        if (attempt > maxRetries) {
          throw DatabaseOperationRetriesExhaustedException(
            maxRetries: maxRetries,
            operationName: name,
            lastError: e,
          );
        }

        final delay = _calculateRetryDelay(attempt);
        AppLogger.w(
          '[$operationId] Connection invalid, retrying in ${delay.inMilliseconds}ms ($attempt/$maxRetries)',
          'DatabaseOperation',
        );
        await Future.delayed(delay);
      } on TimeoutException {
        await lease?.dispose();

        throw DatabaseOperationTimeoutException(
          timeout: timeout,
          operationName: name,
        );
      } catch (e, stackTrace) {
        await lease?.dispose();

        // 检查是否需要重试
        final errorStr = e.toString().toLowerCase();
        final isRetryable = errorStr.contains('database_closed') ||
            errorStr.contains('databaseexception') ||
            errorStr.contains('busy');

        if (isRetryable && attempt < maxRetries) {
          attempt++;
          final delay = _calculateRetryDelay(attempt);
          AppLogger.w(
            '[$operationId] Retryable error, retrying in ${delay.inMilliseconds}ms ($attempt/$maxRetries): $e',
            'DatabaseOperation',
          );
          await Future.delayed(delay);
        } else {
          throw DatabaseOperationException(
            'Operation execution failed',
            operationName: name,
            originalError: e,
            stackTrace: stackTrace,
          );
        }
      }
    }

    // 这不应该发生，但为了类型安全
    throw DatabaseOperationRetriesExhaustedException(
      maxRetries: maxRetries,
      operationName: name,
    );
  }

  /// 计算重试延迟（指数退避）
  ///
  /// 延迟时间 = retryDelay * (2 ^ attempt) + 随机抖动
  Duration _calculateRetryDelay(int attempt) {
    final baseDelay = retryDelay.inMilliseconds;
    final exponentialDelay = baseDelay * math.pow(2, attempt - 1);
    final jitter = (math.Random().nextDouble() * 100).round();
    return Duration(milliseconds: exponentialDelay.toInt() + jitter);
  }

  /// 创建简化版操作（无需指定名称）
  ///
  /// [executor] 数据库操作函数
  /// [name] 可选的操作名称
  static DatabaseOperation<T> simple<T>(
    Future<T> Function(Database db) executor, {
    String? name,
  }) {
    return DatabaseOperation(
      name: name ?? 'unnamed_operation',
      executor: executor,
    );
  }
}

/// 批量数据库操作包装器
///
/// 提供以下功能：
/// 1. 分批执行操作
/// 2. 每批使用独立连接
/// 3. 批次间让出时间片
/// 4. 支持错误继续/中断模式
/// 5. 流式返回结果
///
/// 示例：
/// ```dart
/// final batchOp = BatchDatabaseOperation<int>(
///   operations: operations,
///   batchSize: 10,
///   continueOnError: true,
/// );
/// await for (final result in batchOp.execute()) {
///   print('Result: $result');
/// }
/// ```
class BatchDatabaseOperation<T> {
  /// 要执行的操作列表
  final List<DatabaseOperation<T>> operations;

  /// 每批大小
  final int batchSize;

  /// 批次间延迟
  final Duration betweenBatches;

  /// 是否在错误时继续
  final bool continueOnError;

  /// 批次完成回调
  final void Function(int batchIndex, int completed, int total)? onBatchComplete;

  /// 批次错误回调
  final void Function(int batchIndex, dynamic error, StackTrace? stackTrace)?
      onBatchError;

  /// 进度回调
  final void Function(int completed, int total)? onProgress;

  /// 创建批量操作
  ///
  /// [operations] 要执行的操作列表
  /// [batchSize] 每批大小，默认 10
  /// [betweenBatches] 批次间延迟，默认 10 毫秒
  /// [continueOnError] 是否在错误时继续执行后续批次，默认 true
  /// [onBatchComplete] 批次完成回调
  /// [onBatchError] 批次错误回调
  /// [onProgress] 进度回调
  BatchDatabaseOperation({
    required this.operations,
    this.batchSize = 10,
    this.betweenBatches = const Duration(milliseconds: 10),
    this.continueOnError = true,
    this.onBatchComplete,
    this.onBatchError,
    this.onProgress,
  });

  /// 流式执行批量操作
  ///
  /// 返回结果流，可以实时获取每个操作的结果
  Stream<T> execute() async* {
    if (operations.isEmpty) {
      return;
    }

    final batches = _chunkOperations(operations, batchSize);
    final total = operations.length;
    var completed = 0;

    AppLogger.i(
      'Starting batch operation: ${batches.length} batches, $total operations total',
      'BatchDatabaseOperation',
    );

    for (var batchIndex = 0; batchIndex < batches.length; batchIndex++) {
      final batch = batches[batchIndex];

      try {
        // 获取连接租借执行整批操作
        final lease = await acquireLease(
          operationId: 'batch#$batchIndex',
          timeout: const Duration(seconds: 5),
        );

        try {
          // 验证连接
          if (!await lease.validate()) {
            throw ConnectionInvalidException(
              operationId: 'batch#$batchIndex',
            );
          }

          // 执行批次内所有操作
          for (final operation in batch) {
            try {
              // 使用同一个连接执行操作
              final result = await lease.execute(
                operation.executor,
                validateBefore: false,
              ).timeout(operation.timeout);

              completed++;
              onProgress?.call(completed, total);
              yield result;
            } catch (e, stackTrace) {
              if (continueOnError) {
                AppLogger.w(
                  'Batch $batchIndex operation ${operation.name} failed, continuing: $e',
                  'BatchDatabaseOperation',
                );
                completed++;
                onProgress?.call(completed, total);
                onBatchError?.call(batchIndex, e, stackTrace);
              } else {
                throw DatabaseOperationException(
                  'Batch operation failed',
                  operationName: operation.name,
                  originalError: e,
                  stackTrace: stackTrace,
                );
              }
            }
          }
        } finally {
          await lease.dispose();
        }

        onBatchComplete?.call(batchIndex, completed, total);

        AppLogger.d(
          'Batch $batchIndex completed (${batch.length} operations)',
          'BatchDatabaseOperation',
        );
      } catch (e, stackTrace) {
        if (continueOnError) {
          AppLogger.w(
            'Batch $batchIndex failed, continuing: $e',
            'BatchDatabaseOperation',
          );
          onBatchError?.call(batchIndex, e, stackTrace);
        } else {
          throw DatabaseOperationException(
            'Batch execution failed',
            operationName: 'batch#$batchIndex',
            originalError: e,
            stackTrace: stackTrace,
          );
        }
      }

      // 批次间让出时间片
      if (betweenBatches > Duration.zero &&
          batchIndex < batches.length - 1) {
        await Future.delayed(betweenBatches);
      }
    }

    AppLogger.i(
      'Batch operation completed: $completed/$total operations',
      'BatchDatabaseOperation',
    );
  }

  /// 执行批量操作并返回结果列表
  ///
  /// 注意：这会等待所有操作完成，可能占用较多内存
  Future<List<T>> executeAsList() async {
    final results = <T>[];
    await for (final result in execute()) {
      results.add(result);
    }
    return results;
  }

  /// 将操作列表分块
  List<List<DatabaseOperation<T>>> _chunkOperations(
    List<DatabaseOperation<T>> list,
    int chunkSize,
  ) {
    final chunks = <List<DatabaseOperation<T>>>[];
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

  /// 从操作函数列表创建批量操作
  ///
  /// [executors] 操作函数列表
  /// [namePrefix] 操作名称前缀
  /// [batchSize] 每批大小
  /// [continueOnError] 是否在错误时继续
  static BatchDatabaseOperation<T> fromExecutors<T>(
    List<Future<T> Function(Database db)> executors, {
    String namePrefix = 'batch_op',
    int batchSize = 10,
    bool continueOnError = true,
  }) {
    final operations = executors.asMap().entries.map((entry) {
      return DatabaseOperation<T>(
        name: '$namePrefix#${entry.key}',
        executor: entry.value,
      );
    }).toList();

    return BatchDatabaseOperation<T>(
      operations: operations,
      batchSize: batchSize,
      continueOnError: continueOnError,
    );
  }
}

/// 事务操作包装器
///
/// 提供以下功能：
/// 1. 事务支持
/// 2. 自动回滚
/// 3. 超时控制
///
/// 示例：
/// ```dart
/// final txnOp = TransactionOperation<List<Map>>(
///   name: 'transferFunds',
///   executor: (txn) async {
///     await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', [100, 1]);
///     await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', [100, 2]);
///     return await txn.rawQuery('SELECT * FROM accounts WHERE id IN (?, ?)', [1, 2]);
///   },
/// );
/// final results = await txnOp.execute();
/// ```
class TransactionOperation<T> {
  /// 事务执行器
  final Future<T> Function(Transaction txn) executor;

  /// 事务名称，用于日志和诊断
  final String name;

  /// 事务超时时间
  final Duration timeout;

  /// 重试次数（事务冲突时）
  final int maxRetries;

  /// 事务完成回调
  final void Function(T result, Duration duration)? onComplete;

  /// 事务回滚回调
  final void Function(dynamic error, Duration duration)? onRollback;

  /// 创建事务操作
  ///
  /// [executor] 事务执行函数，接收 Transaction 对象
  /// [name] 事务名称，用于日志和诊断
  /// [timeout] 事务超时时间，默认 30 秒
  /// [maxRetries] 事务冲突时的最大重试次数，默认 3
  /// [onComplete] 事务完成回调
  /// [onRollback] 事务回滚回调
  TransactionOperation({
    required this.executor,
    required this.name,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.onComplete,
    this.onRollback,
  });

  /// 执行事务操作
  ///
  /// 执行流程：
  /// 1. 获取数据库连接
  /// 2. 开启事务
  /// 3. 执行事务操作
  /// 4. 成功则提交，失败则回滚
  /// 5. 释放连接
  ///
  /// 返回事务结果
  /// 抛出 [DatabaseTransactionException]
  Future<T> execute() async {
    final stopwatch = Stopwatch()..start();
    final operationId = '$name#${DateTime.now().millisecondsSinceEpoch}';

    AppLogger.d('Starting transaction: $operationId', 'TransactionOperation');

    var attempt = 0;

    while (attempt <= maxRetries) {
      ConnectionLease? lease;

      try {
        // 获取连接租借
        lease = await acquireLease(
          operationId: operationId,
          timeout: const Duration(seconds: 5),
        );

        // 验证连接
        if (!await lease.validate()) {
          throw ConnectionInvalidException(operationId: operationId);
        }

        // 使用连接执行事务
        final result = await _executeTransaction(lease.connection);

        await lease.dispose();
        stopwatch.stop();

        AppLogger.i(
          'Transaction completed: $operationId in ${stopwatch.elapsed.inMilliseconds}ms',
          'TransactionOperation',
        );

        onComplete?.call(result, stopwatch.elapsed);
        return result;
      } on DatabaseTransactionException {
        await lease?.dispose();
        rethrow;
      } catch (e, stackTrace) {
        await lease?.dispose();

        // 检查是否是可重试的错误（如 busy/locked）
        final errorStr = e.toString().toLowerCase();
        final isRetryable = errorStr.contains('busy') ||
            errorStr.contains('locked') ||
            errorStr.contains('conflict');

        if (isRetryable && attempt < maxRetries) {
          attempt++;
          final delay = Duration(milliseconds: 50 * attempt);
          AppLogger.w(
            '[$operationId] Transaction conflict, retrying in ${delay.inMilliseconds}ms ($attempt/$maxRetries)',
            'TransactionOperation',
          );
          await Future.delayed(delay);
          continue;
        }

        stopwatch.stop();

        AppLogger.e(
          'Transaction failed: $operationId after ${stopwatch.elapsed.inMilliseconds}ms',
          e,
          stackTrace,
          'TransactionOperation',
        );

        onRollback?.call(e, stopwatch.elapsed);

        throw DatabaseTransactionException(
          'Transaction execution failed',
          operationName: name,
          originalError: e,
          stackTrace: stackTrace,
        );
      }
    }

    // 这不应该发生
    throw DatabaseTransactionException(
      'Transaction failed after max retries',
      operationName: name,
    );
  }

  /// 在数据库连接上执行事务
  Future<T> _executeTransaction(Database db) async {
    T? result;
    dynamic transactionError;
    StackTrace? transactionStackTrace;

    await db.transaction((txn) async {
      try {
        result = await executor(txn).timeout(timeout);
      } catch (e, stackTrace) {
        transactionError = e;
        transactionStackTrace = stackTrace;
        // 抛出异常触发回滚
        rethrow;
      }
    });

    // 检查事务内是否发生错误
    if (transactionError != null) {
      throw DatabaseTransactionException(
        'Transaction rolled back due to error',
        operationName: name,
        originalError: transactionError,
        stackTrace: transactionStackTrace,
      );
    }

    return result as T;
  }

  /// 创建简化版事务操作
  ///
  /// [executor] 事务执行函数
  /// [name] 事务名称
  static TransactionOperation<T> simple<T>(
    Future<T> Function(Transaction txn) executor, {
    String? name,
  }) {
    return TransactionOperation(
      name: name ?? 'unnamed_transaction',
      executor: executor,
    );
  }
}

/// 数据库操作构建器
///
/// 提供流畅的 API 构建复杂操作
///
/// 示例：
/// ```dart
/// final result = await DatabaseOperationBuilder()
///   .withName('getUser')
///   .withTimeout(Duration(seconds: 10))
///   .withRetry(3)
///   .execute((db) => db.query('users', limit: 1));
/// ```
class DatabaseOperationBuilder<T> {
  String _name = 'unnamed';
  Duration _timeout = const Duration(seconds: 30);
  int _maxRetries = 3;
  Duration _retryDelay = const Duration(milliseconds: 200);
  Duration _slowThreshold = const Duration(seconds: 1);
  void Function(Duration)? _onSlow;
  void Function(T, Duration)? _onComplete;
  void Function(dynamic, Duration)? _onError;

  /// 设置操作名称
  DatabaseOperationBuilder<T> withName(String name) {
    _name = name;
    return this;
  }

  /// 设置超时时间
  DatabaseOperationBuilder<T> withTimeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  /// 设置最大重试次数
  DatabaseOperationBuilder<T> withRetry(int maxRetries) {
    _maxRetries = maxRetries;
    return this;
  }

  /// 设置重试延迟
  DatabaseOperationBuilder<T> withRetryDelay(Duration delay) {
    _retryDelay = delay;
    return this;
  }

  /// 设置慢操作阈值
  DatabaseOperationBuilder<T> withSlowThreshold(Duration threshold) {
    _slowThreshold = threshold;
    return this;
  }

  /// 设置慢操作回调
  DatabaseOperationBuilder<T> onSlow(void Function(Duration) callback) {
    _onSlow = callback;
    return this;
  }

  /// 设置完成回调
  DatabaseOperationBuilder<T> onComplete(void Function(T, Duration) callback) {
    _onComplete = callback;
    return this;
  }

  /// 设置错误回调
  DatabaseOperationBuilder<T> onError(void Function(dynamic, Duration) callback) {
    _onError = callback;
    return this;
  }

  /// 执行操作
  Future<T> execute(Future<T> Function(Database db) executor) {
    final operation = DatabaseOperation<T>(
      name: _name,
      executor: executor,
      timeout: _timeout,
      maxRetries: _maxRetries,
      retryDelay: _retryDelay,
      slowOperationThreshold: _slowThreshold,
      onSlowOperation: _onSlow,
      onComplete: _onComplete,
      onError: _onError,
    );
    return operation.execute();
  }
}

/// 便捷函数：快速执行数据库操作
///
/// [executor] 数据库操作函数
/// [name] 操作名称
/// [timeout] 超时时间
Future<T> runDatabaseOperation<T>(
  Future<T> Function(Database db) executor, {
  String? name,
  Duration? timeout,
}) async {
  final operation = DatabaseOperation<T>(
    name: name ?? 'quick_op',
    executor: executor,
    timeout: timeout ?? const Duration(seconds: 30),
  );
  return operation.execute();
}

/// 便捷函数：快速执行事务
///
/// [executor] 事务执行函数
/// [name] 事务名称
/// [timeout] 超时时间
Future<T> runTransaction<T>(
  Future<T> Function(Transaction txn) executor, {
  String? name,
  Duration? timeout,
}) async {
  final operation = TransactionOperation<T>(
    name: name ?? 'quick_txn',
    executor: executor,
    timeout: timeout ?? const Duration(seconds: 30),
  );
  return operation.execute();
}

/// 便捷函数：批量执行操作
///
/// [operations] 操作列表
/// [batchSize] 每批大小
/// [continueOnError] 是否在错误时继续
Stream<T> runBatchOperations<T>(
  List<DatabaseOperation<T>> operations, {
  int batchSize = 10,
  bool continueOnError = true,
}) {
  final batch = BatchDatabaseOperation<T>(
    operations: operations,
    batchSize: batchSize,
    continueOnError: continueOnError,
  );
  return batch.execute();
}
