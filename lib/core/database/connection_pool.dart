import 'dart:async';
import 'dart:collection';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';

/// 数据库连接池
///
/// 管理SQLite数据库连接的获取和释放，支持并发安全
class ConnectionPool {
  ConnectionPool._({
    required this.dbPath,
    this.maxConnections = 3,
  });

  static ConnectionPool? _instance;

  /// 获取单例实例
  static ConnectionPool get instance {
    if (_instance == null) {
      throw StateError(
        'ConnectionPool not initialized. Call initialize() first.',
      );
    }
    return _instance!;
  }

  /// 初始化连接池
  static Future<void> initialize({
    required String dbPath,
    int maxConnections = 3,
  }) async {
    if (_instance != null) {
      AppLogger.w('ConnectionPool already initialized', 'ConnectionPool');
      return;
    }

    _instance = ConnectionPool._(
      dbPath: dbPath,
      maxConnections: maxConnections,
    );
    await _instance!._init();
    AppLogger.i('ConnectionPool initialized', 'ConnectionPool');
  }

  final String dbPath;
  final int maxConnections;

  final Queue<Database> _availableConnections = Queue<Database>();
  final Set<Database> _inUseConnections = <Database>{};
  final _lock = Mutex();

  bool _initialized = false;
  bool _disposed = false;

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 是否已释放
  bool get isDisposed => _disposed;

  /// 获取可用连接数
  int get availableCount => _availableConnections.length;

  /// 获取使用中连接数
  int get inUseCount => _inUseConnections.length;

  /// 初始化连接池
  Future<void> _init() async {
    if (_initialized) return;

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
  Future<Database> _createConnection() async {
    return await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        singleInstance: false,
      ),
    );
  }

  /// 获取数据库连接
  ///
  /// 如果连接池已满，会等待直到有连接可用
  Future<Database> acquire() async {
    if (_disposed) {
      throw StateError('ConnectionPool has been disposed');
    }

    await _lock.acquire();
    try {
      while (_availableConnections.isEmpty && _inUseConnections.length >= maxConnections) {
        _lock.release();
        await Future.delayed(const Duration(milliseconds: 10));
        await _lock.acquire();
      }

      if (_availableConnections.isNotEmpty) {
        final db = _availableConnections.removeFirst();
        _inUseConnections.add(db);
        AppLogger.d(
          'Connection acquired (available: $availableCount, inUse: $inUseCount)',
          'ConnectionPool',
        );
        return db;
      }

      // 如果仍然没有可用连接，创建一个新的（超出maxConnections限制）
      AppLogger.w(
        'Creating emergency connection beyond pool limit',
        'ConnectionPool',
      );
      final db = await _createConnection();
      _inUseConnections.add(db);
      return db;
    } finally {
      _lock.release();
    }
  }

  /// 释放数据库连接
  ///
  /// 将连接返回到连接池中
  Future<void> release(Database db) async {
    if (_disposed) {
      await db.close();
      return;
    }

    await _lock.acquire();
    try {
      if (_inUseConnections.contains(db)) {
        _inUseConnections.remove(db);

        // 检查连接是否仍然有效
        if (db.isOpen) {
          _availableConnections.add(db);
          AppLogger.d(
            'Connection released (available: $availableCount, inUse: $inUseCount)',
            'ConnectionPool',
          );
        } else {
          // 连接已关闭，创建新连接
          AppLogger.w('Connection was closed, creating new one', 'ConnectionPool');
          final newDb = await _createConnection();
          _availableConnections.add(newDb);
        }
      }
    } finally {
      _lock.release();
    }
  }

  /// 关闭所有连接
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

      // 关闭所有使用中的连接
      for (final db in _inUseConnections) {
        if (db.isOpen) {
          await db.close();
        }
      }
      _inUseConnections.clear();

      _instance = null;
      _initialized = false;

      AppLogger.i('ConnectionPool disposed', 'ConnectionPool');
    } finally {
      _lock.release();
    }
  }

  /// 重置连接池
  ///
  /// 关闭所有连接并重新创建
  Future<void> reset() async {
    await _lock.acquire();
    try {
      // 关闭所有连接
      for (final db in _availableConnections) {
        if (db.isOpen) {
          await db.close();
        }
      }
      _availableConnections.clear();

      for (final db in _inUseConnections) {
        if (db.isOpen) {
          await db.close();
        }
      }
      _inUseConnections.clear();

      _initialized = false;

      // 重新初始化
      await _init();

      AppLogger.i('ConnectionPool reset', 'ConnectionPool');
    } finally {
      _lock.release();
    }
  }
}

/// 简单的互斥锁实现
class Mutex {
  Future<void>? _lock;

  Future<void> acquire() async {
    while (_lock != null) {
      await _lock;
    }
    final completer = Completer<void>();
    _lock = completer.future;
  }

  void release() {
    final lock = _lock;
    _lock = null;
    if (lock != null && lock is! Completer) {
      (lock as dynamic).complete();
    }
  }
}
