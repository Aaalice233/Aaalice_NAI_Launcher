import 'dart:async';

import 'package:collection/collection.dart';

import '../../utils/app_logger.dart';
import '../state/database_state.dart';
import '../state/database_state_machine.dart';

/// 访问请求优先级
enum AccessPriority {
  critical, // 关键操作（如健康检查）
  high, // 高优先级（用户交互）
  normal, // 普通操作
  low, // 后台任务
}

/// 数据库访问请求
class DatabaseAccessRequest<T> {
  final String id;
  final String operation;
  final AccessPriority priority;
  final Future<T> Function() executor;
  final Completer<T> completer;
  final DateTime createdAt;
  final Duration? timeout;

  DatabaseAccessRequest({
    required this.id,
    required this.operation,
    required this.priority,
    required this.executor,
    this.timeout,
  })  : completer = Completer<T>(),
        createdAt = DateTime.now();

  bool get isExpired =>
      timeout != null && DateTime.now().difference(createdAt) > timeout!;
}

/// 数据库访问门控
class DatabaseAccessGate {
  final DatabaseStateMachine _stateMachine;
  final _pendingRequests =
      PriorityQueue<DatabaseAccessRequest>((a, b) {
    return a.priority.index.compareTo(b.priority.index);
  });
  final _activeOperations = <String, DatabaseAccessRequest>{};

  bool _isProcessing = false;
  final int _maxConcurrentOperations = 3;

  DatabaseAccessGate(this._stateMachine) {
    // 监听状态变化
    _stateMachine.stateChanges.listen(_onStateChange);
  }

  /// 请求数据库访问
  Future<T> request<T>(
    String operation,
    Future<T> Function() executor, {
    AccessPriority priority = AccessPriority.normal,
    Duration timeout = const Duration(seconds: 30),
    bool waitForReady = true,
    // 关键修复：允许在清除状态下执行（用于清除操作内部）
    bool allowDuringClearing = false,
  }) async {
    final request = DatabaseAccessRequest<T>(
      id:
          '${operation}_${DateTime.now().millisecondsSinceEpoch}_${_pendingRequests.length}',
      operation: operation,
      priority: priority,
      executor: executor,
      timeout: timeout,
    );

    // 如果数据库已就绪，直接执行
    if (_stateMachine.isOperational) {
      return _executeRequest(request);
    }

    // 关键修复：如果在清除状态且允许，直接执行（用于清除操作自身）
    if (_stateMachine.currentState == DatabaseState.clearing &&
        allowDuringClearing) {
      AppLogger.d(
        'Allowing request during clearing (allowDuringClearing=true): $operation',
        'DatabaseAccessGate',
      );
      return _executeRequest(request);
    }

    // 如果不等待就绪，立即报错
    if (!waitForReady) {
      throw DatabaseNotReadyException(
        'Database is not ready (current state: ${_stateMachine.currentState.name})',
      );
    }

    // 如果在清除/关闭状态，拒绝请求
    if (_stateMachine.currentState == DatabaseState.closing ||
        _stateMachine.currentState == DatabaseState.clearing) {
      throw DatabaseUnavailableException(
        'Database is temporarily unavailable due to ${_stateMachine.currentState.name}',
      );
    }

    // 加入队列等待
    AppLogger.d(
      'Queuing database request: ${request.operation} (priority: ${priority.name})',
      'DatabaseAccessGate',
    );

    _pendingRequests.add(request);
    _processQueue();

    return request.completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(request);
        throw TimeoutException('Database request timed out: $operation');
      },
    );
  }

  /// 执行请求
  Future<T> _executeRequest<T>(DatabaseAccessRequest<T> request) async {
    _activeOperations[request.id] = request;

    try {
      AppLogger.d(
          'Executing database request: ${request.operation}', 'DatabaseAccessGate',);
      final result = await request.executor();
      request.completer.complete(result);
      return result;
    } catch (e, stack) {
      AppLogger.e(
        'Database request failed: ${request.operation}',
        e,
        stack,
        'DatabaseAccessGate',
      );
      request.completer.completeError(e, stack);
      rethrow;
    } finally {
      _activeOperations.remove(request.id);
      _processQueue();
    }
  }

  /// 处理队列
  void _processQueue() {
    if (_isProcessing) return;
    if (!_stateMachine.isOperational) return;
    if (_activeOperations.length >= _maxConcurrentOperations) return;
    if (_pendingRequests.isEmpty) return;

    _isProcessing = true;

    while (_pendingRequests.isNotEmpty &&
        _activeOperations.length < _maxConcurrentOperations &&
        _stateMachine.isOperational) {
      final request = _pendingRequests.removeFirst();

      // 检查是否过期
      if (request.isExpired) {
        request.completer.completeError(
          TimeoutException(
              'Request expired while waiting: ${request.operation}',),
        );
        continue;
      }

      // 异步执行
      _executeRequest(request);
    }

    _isProcessing = false;
  }

  /// 状态变化处理
  void _onStateChange(DatabaseStateChange change) {
    if (change.current == DatabaseState.ready) {
      // 数据库就绪，处理积压的请求
      _processQueue();
    } else if (change.current == DatabaseState.closing ||
        change.current == DatabaseState.clearing) {
      // 数据库即将关闭，清理过期请求
      _cleanupPendingRequests();
    }
  }

  /// 清理待处理请求
  void _cleanupPendingRequests() {
    final expiredRequests = <DatabaseAccessRequest>[];

    while (_pendingRequests.isNotEmpty) {
      final request = _pendingRequests.removeFirst();
      if (request.isExpired) {
        expiredRequests.add(request);
      } else {
        // 非过期请求在恢复后重新处理
        request.completer.completeError(
          DatabaseUnavailableException(
            'Database operation cancelled due to ${_stateMachine.currentState.name}',
          ),
        );
      }
    }

    for (final request in expiredRequests) {
      request.completer.completeError(
        TimeoutException(
          'Request expired: ${request.operation}',
        ),
      );
    }
  }

  /// 暂停接受新请求（用于清除操作）
  Future<void> pauseNewRequests() async {
    AppLogger.i('Pausing new database requests', 'DatabaseAccessGate');
    // 等待当前活动操作完成
    while (_activeOperations.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// 获取当前状态
  Map<String, dynamic> get status => {
        'currentState': _stateMachine.currentState.name,
        'pendingRequests': _pendingRequests.length,
        'activeOperations': _activeOperations.length,
        'isOperational': _stateMachine.isOperational,
      };
}

/// 自定义异常
class DatabaseNotReadyException implements Exception {
  final String message;
  DatabaseNotReadyException(this.message);
  @override
  String toString() => 'DatabaseNotReadyException: $message';
}

class DatabaseUnavailableException implements Exception {
  final String message;
  DatabaseUnavailableException(this.message);
  @override
  String toString() => 'DatabaseUnavailableException: $message';
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}
