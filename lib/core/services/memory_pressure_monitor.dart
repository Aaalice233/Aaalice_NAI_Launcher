import 'dart:async';
import 'dart:io';

import '../utils/app_logger.dart';

/// 内存压力等级
///
/// 表示系统内存压力的不同级别，用于触发不同的缓存淘汰策略
enum MemoryPressureLevel {
  /// 正常状态，无需处理
  nominal,

  /// 轻微压力，可以开始清理非必要缓存
  fair,

  /// 中等压力，需要积极清理缓存
  serious,

  /// 严重压力，必须立即释放所有可释放内存
  critical,
}

/// 内存压力事件
///
/// 包含内存压力等级和相关元数据
class MemoryPressureEvent {
  /// 压力等级
  final MemoryPressureLevel level;

  /// 事件时间戳
  final DateTime timestamp;

  /// 当前内存使用估算（字节），可能为null
  final int? memoryUsageBytes;

  /// 内存使用率（0.0 - 1.0），可能为null
  final double? memoryUsageRatio;

  /// 触发原因描述
  final String? reason;

  const MemoryPressureEvent({
    required this.level,
    required this.timestamp,
    this.memoryUsageBytes,
    this.memoryUsageRatio,
    this.reason,
  });

  @override
  String toString() =>
      'MemoryPressureEvent(level: $level, memoryUsage: ${memoryUsageBytes != null ? "${(memoryUsageBytes! / 1024 / 1024).toStringAsFixed(1)}MB" : "unknown"}, '
      'ratio: ${memoryUsageRatio?.toStringAsFixed(2) ?? "unknown"}, reason: $reason)';
}

/// 内存统计信息
///
/// 包含当前内存使用情况的详细信息
class MemoryStats {
  /// 当前堆内存使用量（字节）
  final int heapUsage;

  /// 当前堆内存容量（字节）
  final int heapCapacity;

  /// 扩展内存使用量（字节，可能包括图片缓存等）
  final int? extendedUsage;

  /// RSS（Resident Set Size）内存（字节），可能为null
  final int? rssBytes;

  /// 采样时间戳
  final DateTime timestamp;

  const MemoryStats({
    required this.heapUsage,
    required this.heapCapacity,
    this.extendedUsage,
    this.rssBytes,
    required this.timestamp,
  });

  /// 堆内存使用率（0.0 - 1.0）
  double get heapUsageRatio =>
      heapCapacity > 0 ? heapUsage / heapCapacity : 0.0;

  /// 估算的总内存使用（字节）
  int get estimatedTotalUsage =>
      (rssBytes ?? extendedUsage ?? heapUsage);

  /// 格式化显示内存大小
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)}GB';
  }

  @override
  String toString() =>
      'MemoryStats(heap: ${formatBytes(heapUsage)}/${formatBytes(heapCapacity)}, '
      'ratio: ${(heapUsageRatio * 100).toStringAsFixed(1)}%, '
      'rss: ${rssBytes != null ? formatBytes(rssBytes!) : "unknown"})';
}

/// 内存压力监听器回调类型
///
/// 当内存压力变化时触发
typedef MemoryPressureCallback = void Function(MemoryPressureEvent event);

/// 内存压力监控服务
///
/// 监听系统内存压力信号，定期采样内存使用情况，
/// 并在内存压力达到阈值时通知监听器。
///
/// 使用示例：
/// ```dart
/// final monitor = MemoryPressureMonitor.instance;
/// monitor.addListener((event) {
///   if (event.level == MemoryPressureLevel.critical) {
///     // 立即清理所有缓存
///   }
/// });
/// monitor.startMonitoring();
/// ```
class MemoryPressureMonitor {
  MemoryPressureMonitor._() {
    _initThresholds();
  }

  /// 内存使用率阈值配置
  static const double _fairThreshold = 0.6; // 60%
  static const double _seriousThreshold = 0.75; // 75%
  static const double _criticalThreshold = 0.85; // 85%

  /// 默认采样间隔
  static const Duration _defaultSampleInterval = Duration(seconds: 10);

  /// 最小采样间隔（防止过于频繁采样）
  static const Duration _minSampleInterval = Duration(seconds: 1);

  /// 监听器列表
  final List<MemoryPressureCallback> _listeners = [];

  /// 当前压力等级
  MemoryPressureLevel _currentLevel = MemoryPressureLevel.nominal;

  /// 采样定时器
  Timer? _sampleTimer;

  /// 上次内存统计
  MemoryStats? _lastStats;

  /// 是否正在监控
  bool get isMonitoring => _sampleTimer?.isActive ?? false;

  /// 获取当前压力等级
  MemoryPressureLevel get currentLevel => _currentLevel;

  /// 获取上次内存统计
  MemoryStats? get lastStats => _lastStats;

  /// 压力等级变化流控制器
  final _pressureLevelController =
      StreamController<MemoryPressureEvent>.broadcast();

  /// 内存统计流控制器
  final _statsController = StreamController<MemoryStats>.broadcast();

  /// 压力等级变化流
  Stream<MemoryPressureEvent> get onPressureChange =>
      _pressureLevelController.stream;

  /// 内存统计流
  Stream<MemoryStats> get onStatsUpdate => _statsController.stream;

  /// 初始化阈值配置
  void _initThresholds() {
    // 可以从配置中读取自定义阈值
    // 当前使用默认值
    AppLogger.d(
      'Memory thresholds initialized: fair=$_fairThreshold, '
      'serious=$_seriousThreshold, critical=$_criticalThreshold',
      'MemoryPressure',
    );
  }

  /// 开始监控内存压力
  ///
  /// [sampleInterval] 采样间隔，默认10秒
  void startMonitoring({Duration sampleInterval = _defaultSampleInterval}) {
    if (isMonitoring) {
      AppLogger.w('Memory monitoring already started', 'MemoryPressure');
      return;
    }

    final interval =
        sampleInterval < _minSampleInterval ? _minSampleInterval : sampleInterval;

    AppLogger.i(
      'Starting memory pressure monitoring (interval: ${interval.inSeconds}s)',
      'MemoryPressure',
    );

    // 立即执行一次采样
    _sampleMemory();

    // 启动定时采样
    _sampleTimer = Timer.periodic(interval, (_) => _sampleMemory());
  }

  /// 停止监控内存压力
  void stopMonitoring() {
    if (!isMonitoring) {
      return;
    }

    AppLogger.i('Stopping memory pressure monitoring', 'MemoryPressure');
    _sampleTimer?.cancel();
    _sampleTimer = null;
  }

  /// 采样当前内存使用情况
  void _sampleMemory() {
    try {
      final stats = _collectMemoryStats();
      _lastStats = stats;

      // 发送统计更新
      _statsController.add(stats);

      // 检查压力等级变化
      _checkPressureLevel(stats);
    } catch (e) {
      AppLogger.e('Failed to sample memory', e, null, 'MemoryPressure');
    }
  }

  /// 收集内存统计信息
  MemoryStats _collectMemoryStats() {
    // 获取Dart堆内存信息
    final currentHeap = ProcessInfo.currentRss;
    final heapCapacity = ProcessInfo.maxRss;

    // 扩展内存使用估算（包括Flutter图片缓存等）
    // 注意：这是估算值，实际内存使用可能更高
    final extendedUsage = _estimateExtendedMemory();

    return MemoryStats(
      heapUsage: currentHeap,
      heapCapacity: heapCapacity > 0 ? heapCapacity : currentHeap * 2,
      extendedUsage: extendedUsage,
      rssBytes: currentHeap,
      timestamp: DateTime.now(),
    );
  }

  /// 估算扩展内存使用
  ///
  /// 包括图片缓存等非Dart堆内存
  int? _estimateExtendedMemory() {
    try {
      // 获取图片缓存大小
      // 注意：Flutter的ImageCache信息需要通过其他方式获取
      // 这里返回null表示无法精确估算
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查内存压力等级
  void _checkPressureLevel(MemoryStats stats) {
    final ratio = stats.heapUsageRatio;
    MemoryPressureLevel newLevel;

    if (ratio >= _criticalThreshold) {
      newLevel = MemoryPressureLevel.critical;
    } else if (ratio >= _seriousThreshold) {
      newLevel = MemoryPressureLevel.serious;
    } else if (ratio >= _fairThreshold) {
      newLevel = MemoryPressureLevel.fair;
    } else {
      newLevel = MemoryPressureLevel.nominal;
    }

    // 压力等级变化时触发通知
    if (newLevel != _currentLevel || newLevel != MemoryPressureLevel.nominal) {
      _currentLevel = newLevel;

      final event = MemoryPressureEvent(
        level: newLevel,
        timestamp: DateTime.now(),
        memoryUsageBytes: stats.estimatedTotalUsage,
        memoryUsageRatio: ratio,
        reason: _getPressureReason(newLevel, ratio),
      );

      // 发送流到控制器
      _pressureLevelController.add(event);

      // 通知所有监听器
      _notifyListeners(event);

      _logPressureEvent(event);
    }
  }

  /// 获取压力原因描述
  String? _getPressureReason(MemoryPressureLevel level, double ratio) {
    switch (level) {
      case MemoryPressureLevel.nominal:
        return null;
      case MemoryPressureLevel.fair:
        return 'Memory usage at ${(ratio * 100).toStringAsFixed(1)}%';
      case MemoryPressureLevel.serious:
        return 'High memory usage at ${(ratio * 100).toStringAsFixed(1)}%';
      case MemoryPressureLevel.critical:
        return 'Critical memory usage at ${(ratio * 100).toStringAsFixed(1)}%';
    }
  }

  /// 记录压力事件日志
  void _logPressureEvent(MemoryPressureEvent event) {
    final message =
        'Memory pressure: ${event.level.name} (${event.memoryUsageRatio != null ? "${(event.memoryUsageRatio! * 100).toStringAsFixed(1)}%" : "unknown"})';

    switch (event.level) {
      case MemoryPressureLevel.nominal:
        AppLogger.d(message, 'MemoryPressure');
      case MemoryPressureLevel.fair:
        AppLogger.i(message, 'MemoryPressure');
      case MemoryPressureLevel.serious:
        AppLogger.w(message, 'MemoryPressure');
      case MemoryPressureLevel.critical:
        AppLogger.e(message, null, null, 'MemoryPressure');
    }
  }

  /// 添加内存压力监听器
  ///
  /// 监听器将在每次压力等级变化时被调用
  void addListener(MemoryPressureCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// 移除内存压力监听器
  void removeListener(MemoryPressureCallback listener) {
    _listeners.remove(listener);
  }

  /// 通知所有监听器
  void _notifyListeners(MemoryPressureEvent event) {
    for (final listener in _listeners) {
      try {
        listener(event);
      } catch (e) {
        AppLogger.w('Memory pressure listener failed: $e', 'MemoryPressure');
      }
    }
  }

  /// 获取当前内存统计（同步）
  ///
  /// 如果最近没有采样，会执行一次采样
  MemoryStats getCurrentStats() {
    if (_lastStats == null ||
        DateTime.now().difference(_lastStats!.timestamp) >
            const Duration(seconds: 5)) {
      _sampleMemory();
    }
    return _lastStats!;
  }

  /// 强制触发一次内存检查
  ///
  /// 可以手动调用以立即检查内存状态
  MemoryPressureEvent? forceCheck() {
    _sampleMemory();
    return _currentLevel != MemoryPressureLevel.nominal
        ? MemoryPressureEvent(
            level: _currentLevel,
            timestamp: DateTime.now(),
            memoryUsageBytes: _lastStats?.estimatedTotalUsage,
            memoryUsageRatio: _lastStats?.heapUsageRatio,
            reason: 'Manual check',
          )
        : null;
  }

  /// 释放资源
  ///
  /// 在应用退出或不再需要监控时调用
  void dispose() {
    stopMonitoring();
    _pressureLevelController.close();
    _statsController.close();
    _listeners.clear();
    AppLogger.i('Memory pressure monitor disposed', 'MemoryPressure');
  }

  /// 获取建议的缓存大小限制
  ///
  /// 根据当前内存压力返回建议的缓存大小限制
  /// 返回值是内存字节数，null表示无限制
  int? getRecommendedCacheLimit() {
    final stats = _lastStats;
    if (stats == null) return null;

    final availableMemory = stats.heapCapacity - stats.heapUsage;

    switch (_currentLevel) {
      case MemoryPressureLevel.nominal:
        // 可以使用最多50%的可用内存
        return (availableMemory * 0.5).toInt();
      case MemoryPressureLevel.fair:
        // 限制为30%的可用内存
        return (availableMemory * 0.3).toInt();
      case MemoryPressureLevel.serious:
        // 限制为15%的可用内存
        return (availableMemory * 0.15).toInt();
      case MemoryPressureLevel.critical:
        // 紧急情况下建议零缓存
        return 0;
    }
  }

  /// 单例实例
  static final MemoryPressureMonitor instance = MemoryPressureMonitor._();
}
