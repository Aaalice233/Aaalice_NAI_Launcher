import 'dart:async';

import '../utils/app_logger.dart';
import 'connection_pool_holder.dart';

/// 连接池状态
enum PoolState {
  uninitialized,
  creating,
  ready,
  closing,
  closed,
  error,
}

/// 连接池生命周期管理器
class ConnectionPoolLifecycleManager {
  PoolState _state = PoolState.uninitialized;
  String? _dbPath;
  int _maxConnections = 3;

  final _stateController = StreamController<PoolState>.broadcast();

  /// 状态流
  Stream<PoolState> get stateStream => _stateController.stream;

  /// 当前状态
  PoolState get state => _state;

  /// 是否已就绪
  bool get isReady =>
      _state == PoolState.ready && ConnectionPoolHolder.isInitialized;

  /// 获取数据库路径
  String? get dbPath => _dbPath;

  /// 与 ConnectionPoolHolder 状态同步
  ///
  /// 当 ConnectionPoolHolder 已初始化但 manager 状态不一致时调用
  void syncWithHolder() {
    if (ConnectionPoolHolder.isInitialized) {
      if (_state != PoolState.ready && _state != PoolState.creating) {
        AppLogger.i(
          'Syncing manager state with ConnectionPoolHolder: $_state -> ready',
          'ConnectionPoolLifecycle',
        );
        _setState(PoolState.ready);
      }
    } else {
      if (_state != PoolState.uninitialized && _state != PoolState.closed) {
        AppLogger.i(
          'Syncing manager state with ConnectionPoolHolder: $_state -> uninitialized',
          'ConnectionPoolLifecycle',
        );
        _setState(PoolState.uninitialized);
      }
    }
  }

  /// 初始化
  Future<void> initialize({
    required String dbPath,
    int maxConnections = 3,
  }) async {
    _dbPath = dbPath;
    _maxConnections = maxConnections;
    
    // 首先尝试同步状态（如果 Holder 已初始化）
    syncWithHolder();
    
    await createPool();
  }

  /// 创建连接池
  Future<void> createPool() async {
    // 关键修复：更严格的状态检查，考虑 ConnectionPoolHolder 的实际状态
    if (_state == PoolState.creating) {
      AppLogger.w(
        'Pool creation already in progress',
        'ConnectionPoolLifecycle',
      );
      return;
    }

    // 如果已经就绪且 ConnectionPoolHolder 已初始化，直接返回
    if (_state == PoolState.ready && ConnectionPoolHolder.isInitialized) {
      AppLogger.d(
        'Pool already exists and ready',
        'ConnectionPoolLifecycle',
      );
      return;
    }

    // 如果 ConnectionPoolHolder 已初始化但我们状态不对，先关闭再创建
    if (ConnectionPoolHolder.isInitialized) {
      AppLogger.w(
        'ConnectionPoolHolder initialized but state is $_state, resetting...',
        'ConnectionPoolLifecycle',
      );
      await resetPool();
      return;
    }

    // 检查是否已初始化
    if (_dbPath == null) {
      throw StateError(
        'ConnectionPoolLifecycleManager not initialized. '
        'Call initialize() before createPool().',
      );
    }

    _setState(PoolState.creating);

    try {
      // 确保旧池已关闭
      await _closeExistingPool();

      // 创建新池
      await ConnectionPoolHolder.initialize(
        dbPath: _dbPath!,
        maxConnections: _maxConnections,
      );

      _setState(PoolState.ready);
      AppLogger.i(
        'Connection pool created successfully',
        'ConnectionPoolLifecycle',
      );
    } catch (e, stack) {
      _setState(PoolState.error);
      AppLogger.e(
        'Failed to create connection pool',
        e,
        stack,
        'ConnectionPoolLifecycle',
      );
      rethrow;
    }
  }

  /// 关闭连接池
  Future<void> closePool() async {
    if (_state == PoolState.closed || _state == PoolState.closing) {
      return;
    }

    _setState(PoolState.closing);
    await _closeExistingPool();
    _setState(PoolState.closed);
  }

  /// 重置连接池（用于恢复后）
  ///
  /// 关键修复：使用 ConnectionPoolHolder.reset 确保原子性替换
  Future<void> resetPool() async {
    AppLogger.i('Resetting connection pool', 'ConnectionPoolLifecycle');

    if (_dbPath == null) {
      throw StateError('Cannot reset pool: dbPath not set');
    }

    _setState(PoolState.creating);

    try {
      // 关键修复：直接使用 ConnectionPoolHolder.reset
      await ConnectionPoolHolder.reset(
        dbPath: _dbPath!,
        maxConnections: _maxConnections,
      );

      // 关键修复：验证连接池真正准备好
      await _verifyPoolReady();

      _setState(PoolState.ready);
      AppLogger.i('Connection pool reset successfully', 'ConnectionPoolLifecycle');
    } catch (e, stack) {
      _setState(PoolState.error);
      AppLogger.e(
        'Failed to reset connection pool',
        e,
        stack,
        'ConnectionPoolLifecycle',
      );
      rethrow;
    }
  }

  /// 验证连接池已就绪
  Future<void> _verifyPoolReady() async {
    var attempts = 0;
    const maxAttempts = 10;
    
    while (attempts < maxAttempts) {
      try {
        // 尝试获取并释放一个连接来验证池是否真正就绪
        final pool = ConnectionPoolHolder.instance;
        final db = await pool.acquire();
        await pool.release(db);
        AppLogger.d('Connection pool verified ready', 'ConnectionPoolLifecycle');
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          throw StateError('Connection pool failed to become ready after $maxAttempts attempts: $e');
        }
        AppLogger.d(
          'Waiting for connection pool to be ready (attempt $attempts/$maxAttempts)...',
          'ConnectionPoolLifecycle',
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// 关闭现有连接池
  Future<void> _closeExistingPool() async {
    if (!ConnectionPoolHolder.isInitialized) {
      return;
    }

    AppLogger.d('Closing existing connection pool', 'ConnectionPoolLifecycle');

    // 等待所有连接释放
    final pool = ConnectionPoolHolder.getInstanceOrNull();
    if (pool != null) {
      var attempts = 0;
      while (pool.inUseCount > 0 && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (pool.inUseCount > 0) {
        AppLogger.w(
          'Force closing pool with ${pool.inUseCount} connections in use',
          'ConnectionPoolLifecycle',
        );
      }
    }

    await ConnectionPoolHolder.dispose();
  }

  /// WAL checkpoint
  Future<void> walCheckpoint() async {
    if (!isReady) return;

    try {
      final pool = ConnectionPoolHolder.instance;
      final db = await pool.acquire();
      try {
        await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
        AppLogger.d('WAL checkpoint completed', 'ConnectionPoolLifecycle');
      } finally {
        await pool.release(db);
      }
    } catch (e) {
      AppLogger.w('WAL checkpoint failed: $e', 'ConnectionPoolLifecycle');
    }
  }

  /// 获取数据库连接（带状态检查）
  Future<dynamic> acquireConnection() async {
    if (!isReady) {
      throw StateError('Connection pool is not ready (state: $_state)');
    }
    return ConnectionPoolHolder.instance.acquire();
  }

  /// 释放数据库连接
  Future<void> releaseConnection(dynamic db) async {
    if (!ConnectionPoolHolder.isInitialized) {
      // 如果池已关闭，直接关闭连接
      if (db.isOpen) {
        await db.close();
      }
      return;
    }
    await ConnectionPoolHolder.instance.release(db);
  }

  void _setState(PoolState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      AppLogger.d(
        'Pool state changed to: ${newState.name}',
        'ConnectionPoolLifecycle',
      );
    }
  }

  void dispose() {
    _closeExistingPool();
    _stateController.close();
  }
}
