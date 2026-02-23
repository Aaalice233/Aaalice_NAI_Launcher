import 'dart:async';
import 'dart:collection';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';

/// 数据库连接池
///
/// 关键改进：
/// 1. 不再是单例，支持创建新实例替换旧实例
/// 2. 提供全局实例持有者，支持热重启时替换
/// 3. 彻底关闭所有连接后才释放文件
/// 4. 使用条件变量通知机制替代忙等待
/// 5. dispose 时添加强制关闭超时机制
class ConnectionPool {
  final String dbPath;
  final int maxConnections;

  final Queue<Database> _availableConnections = Queue<Database>();
  final Set<Database> _inUseConnections = <Database>{};
  final Set<Database> _evictingConnections = <Database>{}; // 即将失效的连接
  final Map<Database, DateTime> _evictingStartTimes = {}; // 记录连接被标记为 evicting 的时间
  final _lock = Mutex();

  // 条件变量通知机制 - 当连接被释放时通知等待者
  final List<Completer<void>> _waiters = [];

  // dispose 超时配置
  static const Duration _evictionTimeout = Duration(seconds: 30);
  Timer? _evictionTimer;

  bool _initialized = false;
  bool _disposed = false;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 是否已释放
  bool get isDisposed => _disposed;

  ConnectionPool({
    required this.dbPath,
    this.maxConnections = 10,
  });

  /// 初始化连接池
  Future<void> initialize() async {
    if (_initialized) return;
    if (_disposed) {
      throw StateError('ConnectionPool has been disposed');
    }

    for (var i = 0; i < maxConnections; i++) {
      final db = await _createConnection();
      _availableConnections.add(db);
    }

    _initialized = true;
    AppLogger.i(
      'Created $maxConnections database connections',
      'ConnectionPool',
    );
  }

  /// 创建新连接
  ///
  /// 使用 singleInstance: false 确保每个连接是独立的实例，
  /// 避免当底层数据库被关闭时影响所有连接。
  Future<Database> _createConnection() async {
    return await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        singleInstance: false,  // 重要：每个连接独立
        onConfigure: (db) async {
          // 启用外键和 WAL 模式
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA journal_mode = WAL');
        },
      ),
    );
  }

  /// 获取数据库连接
  ///
  /// 从池中获取连接，如果连接已失效则自动创建新连接替代
  Future<Database> acquire() async {
    if (_disposed) {
      throw StateError('ConnectionPool has been disposed');
    }
    if (!_initialized) {
      throw StateError('ConnectionPool not initialized');
    }

    final stopwatch = Stopwatch()..start();
    final availableBefore = _availableConnections.length;
    final inUseBefore = _inUseConnections.length;

    await _lock.acquire();
    try {
      // 使用条件变量通知机制替代忙等待
      while (_availableConnections.isEmpty && _inUseConnections.length >= maxConnections) {
        // 创建一个 completer 来等待连接可用通知
        final completer = Completer<void>();
        _waiters.add(completer);
        _lock.release();

        try {
          // 等待通知或超时（避免永久阻塞）
          await completer.future.timeout(
            const Duration(milliseconds: 100),
            onTimeout: () {
              // 超时后重新检查条件
            },
          );
        } finally {
          _waiters.remove(completer);
          await _lock.acquire();
        }
      }

      if (_availableConnections.isNotEmpty) {
        var db = _availableConnections.removeFirst();

        // 验证连接是否仍然有效
        if (!db.isOpen) {
          AppLogger.d('Connection from pool is closed, creating new one', 'ConnectionPool');
          try {
            await db.close();
          } catch (_) {
            // 忽略关闭错误
          }
          db = await _createConnection();
        }

        _inUseConnections.add(db);

        // Log metrics after acquiring connection
        stopwatch.stop();
        _logMetrics(
          availableBefore: availableBefore,
          inUseBefore: inUseBefore,
          acquisitionTimeMs: stopwatch.elapsedMilliseconds,
        );

        return db;
      }

      // 创建临时连接（超出池大小）
      final db = await _createConnection();

      // Log metrics for temporary connection
      stopwatch.stop();
      _logMetrics(
        availableBefore: availableBefore,
        inUseBefore: inUseBefore,
        acquisitionTimeMs: stopwatch.elapsedMilliseconds,
        isTemporary: true,
      );

      return db;
    } finally {
      _lock.release();
    }
  }

  /// 记录连接池指标日志
  void _logMetrics({
    required int availableBefore,
    required int inUseBefore,
    required int acquisitionTimeMs,
    bool isTemporary = false,
  }) {
    final availableNow = _availableConnections.length;
    final inUseNow = _inUseConnections.length;

    // Log warning if available connections is low
    if (availableNow < 2) {
      AppLogger.w(
        'Low available connections: $availableNow (in-use: $inUseNow, acquisition: ${acquisitionTimeMs}ms)',
        'ConnectionPool',
      );
    }

    // Log warning if acquisition time is high
    if (acquisitionTimeMs > 1000) {
      AppLogger.w(
        'Slow connection acquisition: ${acquisitionTimeMs}ms (available: $availableNow, in-use: $inUseNow)',
        'ConnectionPool',
      );
    }

    // Log info for temporary connections
    if (isTemporary) {
      AppLogger.i(
        'Created temporary connection (pool exhausted: $inUseBefore/$maxConnections, acquisition: ${acquisitionTimeMs}ms)',
        'ConnectionPool',
      );
    }
  }

  /// 释放连接
  ///
  /// 关键改进：检查连接是否是"即将失效"的连接（来自旧连接池）。
  /// 如果是，则关闭它而不是放回池中。
  Future<void> release(Database db) async {
    await _lock.acquire();
    try {
      // 检查是否是即将失效的连接（来自正在关闭的连接池）
      if (_evictingConnections.contains(db)) {
        _evictingConnections.remove(db);
        _evictingStartTimes.remove(db);
        _inUseConnections.remove(db);
        if (db.isOpen) {
          await db.close();
          AppLogger.d('Evicted connection closed during release', 'ConnectionPool');
        }
        return;
      }

      // 如果连接池已完全 disposed，直接关闭连接
      if (_disposed) {
        _inUseConnections.remove(db);
        if (db.isOpen) {
          await db.close();
        }
        return;
      }

      if (_inUseConnections.contains(db)) {
        _inUseConnections.remove(db);

        // 检查连接是否仍然有效
        if (db.isOpen) {
          // 如果池已满，关闭此连接
          if (_availableConnections.length >= maxConnections) {
            await db.close();
          } else {
            _availableConnections.add(db);
          }
        }
      } else {
        // 临时连接直接关闭
        if (db.isOpen) {
          await db.close();
        }
      }

      // 通知等待的获取者连接已可用
      _notifyWaiters();
    } finally {
      _lock.release();
    }
  }

  /// 通知等待的获取者有连接可用
  void _notifyWaiters() {
    // 唤醒所有等待者，让它们重新检查条件
    for (final completer in _waiters.toList()) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _waiters.clear();
  }

  /// 优雅关闭连接池
  ///
  /// 关键改进：
  /// 1. 不再强制关闭正在使用的连接，而是标记它们为"即将失效"
  /// 2. 添加超时机制，强制关闭长时间未释放的连接
  /// 3. 通知所有等待的获取者连接池已关闭
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _lock.acquire();
    try {
      // 关闭所有可用连接
      for (final db in _availableConnections) {
        if (db.isOpen) {
          await db.close();
        }
      }
      _availableConnections.clear();

      // 将使用中的连接标记为即将失效，而不是强制关闭
      // 这样正在进行的操作可以继续，但在 release 时会关闭这些连接
      final now = DateTime.now();
      for (final db in _inUseConnections) {
        _evictingConnections.add(db);
        _evictingStartTimes[db] = now;
      }

      final evictingCount = _evictingConnections.length;
      if (evictingCount > 0) {
        AppLogger.w(
          'ConnectionPool graceful shutdown: $evictingCount connections still in use, marked for eviction (timeout: ${_evictionTimeout.inSeconds}s)',
          'ConnectionPool',
        );

        // 启动定时器检查超时连接
        _startEvictionTimer();
      }

      // 通知所有等待者连接池已关闭
      _notifyWaitersWithError(StateError('ConnectionPool has been disposed'));

      AppLogger.i('ConnectionPool disposed (graceful)', 'ConnectionPool');
    } finally {
      _lock.release();
    }
  }

  /// 启动驱逐定时器，强制关闭超时连接
  void _startEvictionTimer() {
    _evictionTimer?.cancel();
    _evictionTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_evictingConnections.isEmpty) {
        timer.cancel();
        return;
      }

      await _lock.acquire();
      try {
        final now = DateTime.now();
        final toForceClose = <Database>[];

        for (final db in _evictingConnections) {
          final startTime = _evictingStartTimes[db];
          if (startTime != null && now.difference(startTime) > _evictionTimeout) {
            toForceClose.add(db);
          }
        }

        for (final db in toForceClose) {
          _evictingConnections.remove(db);
          _evictingStartTimes.remove(db);
          _inUseConnections.remove(db);

          if (db.isOpen) {
            try {
              await db.close();
              AppLogger.w('Force-closed connection after timeout', 'ConnectionPool');
            } catch (e) {
              AppLogger.w('Error force-closing connection: $e', 'ConnectionPool');
            }
          }
        }

        if (_evictingConnections.isEmpty) {
          timer.cancel();
        }
      } finally {
        _lock.release();
      }
    });
  }

  /// 通知所有等待者连接池已关闭
  void _notifyWaitersWithError(Error error) {
    for (final completer in _waiters.toList()) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _waiters.clear();
  }

  /// 获取可用连接数
  int get availableCount => _availableConnections.length;

  /// 获取使用中连接数
  int get inUseCount => _inUseConnections.length;
}

/// 简单的互斥锁实现
class Mutex {
  Completer<void>? _completer;

  Future<void> acquire() async {
    while (true) {
      final current = _completer;
      if (current == null) {
        // 锁空闲，尝试获取
        _completer = Completer<void>();
        return;
      }
      // 锁被占用，等待
      await current.future;
    }
  }

  void release() {
    final current = _completer;
    if (current != null) {
      _completer = null;
      current.complete();
    }
  }
}
