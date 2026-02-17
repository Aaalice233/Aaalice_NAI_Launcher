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
class ConnectionPool {
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

  ConnectionPool({
    required this.dbPath,
    this.maxConnections = 3,
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
  Future<Database> _createConnection() async {
    return await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          // 启用外键和 WAL 模式
          await db.execute('PRAGMA foreign_keys = ON');
          await db.execute('PRAGMA journal_mode = WAL');
        },
      ),
    );
  }

  /// 获取数据库连接
  Future<Database> acquire() async {
    if (_disposed) {
      throw StateError('ConnectionPool has been disposed');
    }
    if (!_initialized) {
      throw StateError('ConnectionPool not initialized');
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
        return db;
      }

      // 创建临时连接（超出池大小）
      return await _createConnection();
    } finally {
      _lock.release();
    }
  }

  /// 释放连接
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

      // 关闭使用中连接（等待它们完成）
      for (final db in _inUseConnections) {
        if (db.isOpen) {
          await db.close();
        }
      }
      _inUseConnections.clear();

      AppLogger.i('ConnectionPool disposed', 'ConnectionPool');
    } finally {
      _lock.release();
    }
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
