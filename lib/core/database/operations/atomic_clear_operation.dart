import '../../utils/app_logger.dart';
import '../connection_pool_lifecycle_manager.dart';
import '../gate/database_access_gate.dart';
import '../state/database_state.dart';
import '../state/database_state_machine.dart';

/// 清除操作结果
class ClearOperationResult {
  final bool success;
  final String? error;
  final int totalRemoved;
  final Map<String, int> tableStats;
  final Duration duration;

  ClearOperationResult({
    required this.success,
    this.error,
    this.totalRemoved = 0,
    this.tableStats = const {},
    required this.duration,
  });

  factory ClearOperationResult.success({
    required int totalRemoved,
    required Map<String, int> tableStats,
    required Duration duration,
  }) =>
      ClearOperationResult(
        success: true,
        totalRemoved: totalRemoved,
        tableStats: tableStats,
        duration: duration,
      );

  factory ClearOperationResult.failure(String error, Duration duration) =>
      ClearOperationResult(
        success: false,
        error: error,
        duration: duration,
      );
}

/// 原子清除操作协调器
class AtomicClearOperation {
  final DatabaseStateMachine _stateMachine;
  final DatabaseAccessGate _accessGate;
  final ConnectionPoolLifecycleManager _lifecycleManager;

  bool _isClearing = false;

  AtomicClearOperation(
    this._stateMachine,
    this._accessGate,
    this._lifecycleManager,
  );

  /// 是否正在清除
  bool get isClearing => _isClearing;

  /// 预热连接池
  ///
  /// 执行一个简单的查询来确保连接池真正准备好处理实际查询。
  /// 这可以防止在 Provider 刷新后立即查询时遇到 database_closed 错误。
  Future<void> _warmUpConnectionPool() async {
    var attempts = 0;
    const maxAttempts = 5;

    while (attempts < maxAttempts) {
      try {
        final db = await _lifecycleManager.acquireConnection();
        try {
          // 执行一个简单的查询来验证连接可用
          await db.rawQuery('SELECT 1');
          AppLogger.d('Connection pool warmed up successfully', 'AtomicClearOperation');
          return;
        } finally {
          await _lifecycleManager.releaseConnection(db);
        }
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          AppLogger.w(
            'Failed to warm up connection pool after $maxAttempts attempts: $e',
            'AtomicClearOperation',
          );
          // 不抛出异常，让操作继续
          return;
        }
        AppLogger.d(
          'Waiting for connection pool to be ready for warm-up (attempt $attempts/$maxAttempts)...',
          'AtomicClearOperation',
        );
        await Future.delayed(Duration(milliseconds: 50 * attempts));
      }
    }
  }

  /// 执行原子清除操作
  Future<ClearOperationResult> execute({
    required Future<Map<String, int>> Function() clearTables,
    required Future<void> Function()? preClear,
    required Future<void> Function()? postClear,
    required List<String> tablesToClear,
  }) async {
    // 防止并发清除
    if (_isClearing) {
      return ClearOperationResult.failure(
        'Clear operation already in progress',
        Duration.zero,
      );
    }

    final stopwatch = Stopwatch()..start();

    _isClearing = true;

    try {
      AppLogger.i('Starting atomic clear operation', 'AtomicClearOperation');

      // 步骤 1: 转换到 clearing 状态
      await _stateMachine.transition(
        DatabaseStateEvent.clear,
        reason: 'Starting atomic clear operation',
      );

      // 步骤 2: 暂停新请求，等待当前操作完成
      await _accessGate.pauseNewRequests();

      // 步骤 3: 执行前置清理（如清除内存缓存）
      if (preClear != null) {
        AppLogger.d('Executing pre-clear callback', 'AtomicClearOperation');
        await preClear();
      }

      // 步骤 4: 执行实际的表清除（在连接池仍可用时）
      AppLogger.d('Clearing database tables', 'AtomicClearOperation');
      final tableStats = await clearTables();

      // 步骤 5: WAL checkpoint（确保数据完全写入）
      // 使用 lifecycleManager 获取连接
      final db = await _lifecycleManager.acquireConnection();
      try {
        await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        AppLogger.d('WAL checkpoint completed', 'AtomicClearOperation');
      } finally {
        await _lifecycleManager.releaseConnection(db);
      }

      // 步骤 6: 重置连接池（使用 reset 替代 close + create，确保状态一致性）
      AppLogger.d('Resetting connection pool', 'AtomicClearOperation');
      await _lifecycleManager.resetPool();

      // 步骤 7: 确保连接池完全准备好
      // 这样当状态转换为 ready 时，连接池一定可用
      AppLogger.d('Verifying connection pool is ready before marking state', 'AtomicClearOperation');
      _lifecycleManager.syncWithHolder();

      // 步骤 8: 转换到 ready 状态（必须在 postClear 之前！）
      // 关键：先转换状态，再刷新 Provider，这样 Provider 看到的就是 ready 状态
      await _stateMachine.transition(
        DatabaseStateEvent.markReady,
        reason: 'Clear operation completed',
      );
      AppLogger.i('Database state is now READY', 'AtomicClearOperation');

      // 步骤 9: 预热连接池（关键修复）
      // 在刷新 Provider 之前，先执行一个实际查询来确保连接池完全准备好
      // 这可以防止 Provider 刷新后的首次查询遇到 database_closed 错误
      AppLogger.d('Warming up connection pool before refreshing providers', 'AtomicClearOperation');
      await _warmUpConnectionPool();

      // 步骤 10: 执行后置清理（刷新 Provider）
      // 现在状态已经是 ready，连接池也已预热，Provider 可以正常查询
      if (postClear != null) {
        AppLogger.d('Executing post-clear callback (refreshing providers)', 'AtomicClearOperation');
        await postClear();
      }
      
      AppLogger.i('Atomic clear operation state transition completed', 'AtomicClearOperation');

      stopwatch.stop();

      final totalRemoved = tableStats.values.fold<int>(
        0,
        (sum, count) => sum + count,
      );

      AppLogger.i(
        'Atomic clear operation completed: $totalRemoved rows removed in ${stopwatch.elapsedMilliseconds}ms',
        'AtomicClearOperation',
      );

      return ClearOperationResult.success(
        totalRemoved: totalRemoved,
        tableStats: tableStats,
        duration: stopwatch.elapsed,
      );
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.e(
        'Atomic clear operation failed',
        e,
        stack,
        'AtomicClearOperation',
      );

      // 尝试恢复
      try {
        // 关键修复：使用 resetPool 而不是 createPool，确保状态一致性
        await _lifecycleManager.resetPool();
        
        // 强制转换到 ready 状态
        final currentState = _stateMachine.currentState;
        AppLogger.w(
          'Recovering from clear failure, current state: $currentState',
          'AtomicClearOperation',
        );
        
        // 尝试转换到 ready 状态（从任何状态）
        try {
          await _stateMachine.transition(
            DatabaseStateEvent.markReady,
            reason: 'Recovery after clear failure',
          );
        } catch (stateError) {
          AppLogger.w(
            'State transition failed during recovery: $stateError',
            'AtomicClearOperation',
          );
          // 忽略状态转换错误，继续执行
        }
      } catch (recoveryError) {
        AppLogger.w(
          'Recovery failed: $recoveryError',
          'AtomicClearOperation',
        );
        // 尝试标记为错误状态
        try {
          await _stateMachine.transition(
            DatabaseStateEvent.markError,
            reason: 'Failed to recover after clear: $recoveryError',
          );
        } catch (e) {
          // 如果标记错误也失败，记录日志但不抛出
          AppLogger.w(
            'Failed to mark error state: $e',
            'AtomicClearOperation',
          );
        }
      }

      return ClearOperationResult.failure(e.toString(), stopwatch.elapsed);
    } finally {
      _isClearing = false;
    }
  }
}
