import 'dart:async';

/// 状态更新节流器
/// 用于控制状态更新的频率，支持时间间隔节流和批量更新
class StateUpdateThrottler<T> {
  final Duration throttleInterval;
  final bool leading;
  final bool trailing;
  final void Function(T value)? onUpdate;
  final void Function(List<T> values)? onBatchUpdate;

  Timer? _throttleTimer;
  T? _pendingValue;
  final List<T> _pendingBatch = [];
  DateTime? _lastUpdateTime;
  bool _isFirstCall = true;
  bool _isThrottlingWindow = false;
  bool _isFlushed = false;

  /// 创建状态更新节流器
  ///
  /// [throttleInterval] - 节流时间间隔
  /// [leading] - 是否在首次调用时立即执行（默认为 true）
  /// [trailing] - 是否在节流间隔结束时执行挂起的更新（默认为 true）
  /// [onUpdate] - 单个值更新回调
  /// [onBatchUpdate] - 批量更新回调（优先于 onUpdate）
  StateUpdateThrottler({
    required this.throttleInterval,
    this.leading = true,
    this.trailing = true,
    this.onUpdate,
    this.onBatchUpdate,
  });

  /// 获取是否有挂起的更新
  bool get hasPendingUpdate => _pendingValue != null || _pendingBatch.isNotEmpty;

  /// 获取是否有挂起的批量更新
  bool get hasPendingBatchUpdate => _pendingBatch.isNotEmpty;

  /// 获取挂起的单个值
  T? get pendingValue => _pendingValue;

  /// 获取挂起的批量值列表
  List<T> get pendingBatch => List.unmodifiable(_pendingBatch);

  /// 获取距离上次更新的时间
  Duration? get timeSinceLastUpdate =>
      _lastUpdateTime != null ? DateTime.now().difference(_lastUpdateTime!) : null;

  /// 是否正在节流等待中
  bool get isThrottling => _isThrottlingWindow;

  /// 触发状态更新
  ///
  /// 根据配置，可能会立即执行或延迟执行
  void throttle(T value) {
    final now = DateTime.now();

    // 首次调用
    if (_isFirstCall) {
      _isFirstCall = false;
      if (leading) {
        // leading=true: 立即执行
        // 执行单个回调
        _executeUpdate(value);
        // 有批量回调时，也执行批次
        if (onBatchUpdate != null) {
          _pendingBatch.add(value);
          _executeBatchUpdate(List.from(_pendingBatch));
          _pendingBatch.clear();
        }
        _lastUpdateTime = now;
        _startThrottleTimer();
      } else {
        // leading=false: 保存为挂起，等待 trailing 执行
        _pendingValue = value;
        _pendingBatch.add(value);
        _startThrottleTimer();
      }
      return;
    }

    // 检查是否在节流间隔内
    if (_isThrottlingWindow) {
      // 在节流间隔内，保存最新值和批次
      _pendingValue = value;
      _pendingBatch.add(value);
      return;
    }

    // 超出节流间隔，立即执行
    if (onBatchUpdate != null) {
      _pendingBatch.add(value);
      _executeBatchUpdate(List.from(_pendingBatch));
      _pendingBatch.clear();
    } else {
      _executeUpdate(value);
    }
    _lastUpdateTime = now;
    _startThrottleTimer();
  }

  /// 批量触发状态更新
  ///
  /// 多个值会被收集并在适当的时机批量处理
  void throttleAll(List<T> values) {
    if (values.isEmpty) return;

    final now = DateTime.now();

    // 首次调用
    if (_isFirstCall) {
      _isFirstCall = false;
      if (leading) {
        // leading=true: 立即批量执行
        _executeBatchUpdate(values);
        _lastUpdateTime = now;
        _startThrottleTimer();
      } else {
        // leading=false: 保存为挂起，等待 trailing 执行
        _pendingBatch.addAll(values);
        if (values.isNotEmpty) {
          _pendingValue = values.last;
        }
        _startThrottleTimer();
      }
      return;
    }

    // 检查是否在节流间隔内
    if (_isThrottlingWindow) {
      // 在节流间隔内，添加到挂起批次
      _pendingBatch.addAll(values);
      if (values.isNotEmpty) {
        _pendingValue = values.last;
      }
      return;
    }

    // 超出节流间隔，立即批量执行
    _executeBatchUpdate(values);
    _lastUpdateTime = now;
    _startThrottleTimer();
  }

  /// 立即刷新挂起的更新
  ///
  /// 如果有挂起的更新，立即执行并清除计时器
  void flush() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _isThrottlingWindow = false;
    _isFlushed = true;

    if (_pendingBatch.isNotEmpty) {
      _executeBatchUpdate(List.from(_pendingBatch));
      _pendingBatch.clear();
      _pendingValue = null;
    } else if (_pendingValue != null) {
      _executeUpdate(_pendingValue as T);
      _pendingValue = null;
    }

    _lastUpdateTime = DateTime.now();
  }

  /// 取消挂起的更新
  ///
  /// 清除所有挂起的更新和计时器，不执行回调
  void cancel() {
    _clearPending();
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _isThrottlingWindow = false;
  }

  /// 重置节流器状态
  ///
  /// 清除所有状态和计时器，恢复到初始状态
  void reset() {
    cancel();
    _isFirstCall = true;
    _lastUpdateTime = null;
    _isFlushed = false;
  }

  /// 释放资源
  ///
  /// 取消计时器并清理资源，节流器不再可用
  void dispose() {
    cancel();
    _pendingBatch.clear();
  }

  /// 执行单个值更新
  void _executeUpdate(T value) {
    onUpdate?.call(value);
  }

  /// 执行批量更新
  void _executeBatchUpdate(List<T> values) {
    if (onBatchUpdate != null) {
      onBatchUpdate!(values);
    } else {
      // 如果没有批量回调，逐个调用单个回调
      for (final value in values) {
        onUpdate?.call(value);
      }
    }
  }

  /// 启动节流计时器
  void _startThrottleTimer() {
    _throttleTimer?.cancel();
    _isThrottlingWindow = true;
    _isFlushed = false;

    _throttleTimer = Timer(throttleInterval, () {
      // 如果已经被 flush 过，不再执行 trailing
      if (_isFlushed) {
        _isThrottlingWindow = false;
        return;
      }
      _isThrottlingWindow = false;
      if (trailing && hasPendingUpdate) {
        // 有批量回调时执行批次，否则只执行最新值
        if (onBatchUpdate != null && _pendingBatch.isNotEmpty) {
          _executeBatchUpdate(List.from(_pendingBatch));
          _pendingBatch.clear();
        } else if (_pendingValue != null) {
          _executeUpdate(_pendingValue as T);
        }
        _pendingValue = null;
      }
      _lastUpdateTime = DateTime.now();
    });
  }

  /// 清除挂起的更新
  void _clearPending() {
    _pendingValue = null;
    _pendingBatch.clear();
  }
}

/// 全局状态更新节流器管理器
/// 用于管理多个命名节流器实例
class StateUpdateThrottlerManager {
  static final Map<String, StateUpdateThrottler> _throttlers = {};

  /// 获取或创建节流器
  static StateUpdateThrottler<T> getOrCreate<T>(
    String key, {
    required Duration throttleInterval,
    bool leading = true,
    bool trailing = true,
    void Function(T value)? onUpdate,
    void Function(List<T> values)? onBatchUpdate,
  }) {
    if (_throttlers.containsKey(key)) {
      return _throttlers[key]! as StateUpdateThrottler<T>;
    }

    final throttler = StateUpdateThrottler<T>(
      throttleInterval: throttleInterval,
      leading: leading,
      trailing: trailing,
      onUpdate: onUpdate,
      onBatchUpdate: onBatchUpdate,
    );
    _throttlers[key] = throttler;
    return throttler;
  }

  /// 获取已存在的节流器
  static StateUpdateThrottler<T>? get<T>(String key) {
    return _throttlers[key] as StateUpdateThrottler<T>?;
  }

  /// 移除节流器
  static void remove(String key) {
    final throttler = _throttlers.remove(key);
    throttler?.dispose();
  }

  /// 清空所有节流器
  static void clear() {
    for (final throttler in _throttlers.values) {
      throttler.dispose();
    }
    _throttlers.clear();
  }

  /// 获取所有节流器的键
  static List<String> get keys => List.unmodifiable(_throttlers.keys);

  /// 检查是否存在指定键的节流器
  static bool hasKey(String key) => _throttlers.containsKey(key);
}
