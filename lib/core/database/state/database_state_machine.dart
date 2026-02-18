import 'dart:async';

import '../../utils/app_logger.dart';
import 'database_state.dart';

/// 状态变化事件
class DatabaseStateChange {
  final DatabaseState previous;
  final DatabaseState current;
  final DatabaseStateEvent? triggerEvent;
  final DateTime timestamp;
  final String? reason;

  DatabaseStateChange({
    required this.previous,
    required this.current,
    this.triggerEvent,
    required this.timestamp,
    this.reason,
  });

  bool get isTransitioning =>
      current == DatabaseState.initializing ||
      current == DatabaseState.closing ||
      current == DatabaseState.recovering ||
      current == DatabaseState.clearing;
}

/// 数据库状态机
class DatabaseStateMachine {
  DatabaseState _currentState = DatabaseState.uninitialized;
  final _stateController = StreamController<DatabaseStateChange>.broadcast();
  final _transitionHistory = <DatabaseStateChange>[];
  static const int _maxHistorySize = 50;

  /// 状态变化流
  Stream<DatabaseStateChange> get stateChanges => _stateController.stream;

  /// 当前状态
  DatabaseState get currentState => _currentState;

  /// 是否处于可操作状态
  bool get isOperational => _currentState == DatabaseState.ready;

  /// 是否处于过渡状态（不应接受新请求）
  bool get isTransitioning => _currentState == DatabaseState.initializing ||
      _currentState == DatabaseState.closing ||
      _currentState == DatabaseState.recovering ||
      _currentState == DatabaseState.clearing;

  /// 是否处于清除状态
  bool get isClearing => _currentState == DatabaseState.clearing;

  /// 历史记录
  List<DatabaseStateChange> get history => List.unmodifiable(_transitionHistory);

  /// 尝试状态转换
  Future<bool> transition(
    DatabaseStateEvent event, {
    String? reason,
    Future<void> Function()? onTransition,
  }) async {
    // 查找有效转换
    final transition = validTransitions.cast<StateTransition?>().firstWhere(
      (t) => t?.from == _currentState && t?.event == event,
      orElse: () => null,
    );

    if (transition == null) {
      throw StateError(
        'Invalid transition: ${_currentState.name} -> ${event.name}',
      );
    }

    final previousState = _currentState;

    AppLogger.i(
      'Database state transition: ${previousState.name} -> ${transition.to.name} '
      '(trigger: ${event.name}, reason: $reason)',
      'DatabaseStateMachine',
    );

    // 执行转换前的操作
    if (onTransition != null) {
      await onTransition();
    }

    // 执行状态转换
    _currentState = transition.to;

    // 记录历史
    final change = DatabaseStateChange(
      previous: previousState,
      current: _currentState,
      triggerEvent: event,
      timestamp: DateTime.now(),
      reason: reason,
    );
    _transitionHistory.add(change);
    if (_transitionHistory.length > _maxHistorySize) {
      _transitionHistory.removeAt(0);
    }

    // 广播状态变化
    _stateController.add(change);

    return true;
  }

  /// 等待特定状态
  Future<DatabaseState> waitForState(
    DatabaseState targetState, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_currentState == targetState) {
      return targetState;
    }

    return stateChanges
        .where((change) => change.current == targetState)
        .map((change) => change.current)
        .first
        .timeout(timeout);
  }

  /// 等待就绪
  Future<void> waitForReady({Duration timeout = const Duration(seconds: 30)}) async {
    await waitForState(DatabaseState.ready, timeout: timeout);
  }

  void dispose() {
    _stateController.close();
  }
}
