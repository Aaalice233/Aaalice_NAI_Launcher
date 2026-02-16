import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/cache_eviction_service.dart';
import '../../core/services/memory_pressure_monitor.dart';
import '../../core/utils/app_logger.dart';

part 'memory_pressure_provider.g.dart';

/// 内存压力状态
///
/// 包含当前内存统计信息和压力等级，用于UI显示和缓存管理决策
class MemoryPressureState {
  /// 当前内存统计
  final MemoryStats? stats;

  /// 当前内存压力等级
  final MemoryPressureLevel pressureLevel;

  /// 是否正在监控
  final bool isMonitoring;

  /// 是否正在执行清理
  final bool isCleaning;

  /// 上次压力事件
  final MemoryPressureEvent? lastEvent;

  /// 建议的缓存限制（字节）
  final int? recommendedCacheLimit;

  const MemoryPressureState({
    this.stats,
    this.pressureLevel = MemoryPressureLevel.nominal,
    this.isMonitoring = false,
    this.isCleaning = false,
    this.lastEvent,
    this.recommendedCacheLimit,
  });

  /// 初始状态
  factory MemoryPressureState.initial() => const MemoryPressureState();

  /// 内存使用率（0.0 - 1.0）
  double? get memoryUsageRatio => stats?.heapUsageRatio;

  /// 格式化后的内存使用显示
  String get memoryUsageText {
    if (stats == null) return 'Unknown';
    return '${MemoryStats.formatBytes(stats!.heapUsage)} / ${MemoryStats.formatBytes(stats!.heapCapacity)}';
  }

  /// 是否需要清理缓存
  bool get shouldCleanCache =>
      pressureLevel == MemoryPressureLevel.serious ||
      pressureLevel == MemoryPressureLevel.critical;

  MemoryPressureState copyWith({
    MemoryStats? stats,
    MemoryPressureLevel? pressureLevel,
    bool? isMonitoring,
    bool? isCleaning,
    MemoryPressureEvent? lastEvent,
    int? recommendedCacheLimit,
  }) {
    return MemoryPressureState(
      stats: stats ?? this.stats,
      pressureLevel: pressureLevel ?? this.pressureLevel,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      isCleaning: isCleaning ?? this.isCleaning,
      lastEvent: lastEvent ?? this.lastEvent,
      recommendedCacheLimit: recommendedCacheLimit ?? this.recommendedCacheLimit,
    );
  }
}

/// 内存压力监控 Provider
///
/// 提供内存压力状态的实时更新，自动监控内存使用情况并触发缓存清理
///
/// 使用示例：
/// ```dart
/// final memoryState = ref.watch(memoryPressureNotifierProvider);
/// final isHighPressure = memoryState.pressureLevel.index >= MemoryPressureLevel.serious.index;
/// ```
@riverpod
class MemoryPressureNotifier extends _$MemoryPressureNotifier {
  /// 内存压力监控器
  late MemoryPressureMonitor _monitor;

  /// 缓存淘汰服务
  CacheEvictionService? _evictionService;

  /// 压力事件流订阅
  StreamSubscription<MemoryPressureEvent>? _pressureSubscription;

  /// 统计信息流订阅
  StreamSubscription<MemoryStats>? _statsSubscription;

  @override
  MemoryPressureState build() {
    // 获取缓存淘汰服务
    _evictionService = ref.read(cacheEvictionServiceProvider);

    // 初始化监控器
    _monitor = MemoryPressureMonitor.instance;

    // 清理资源
    ref.onDispose(() {
      _pressureSubscription?.cancel();
      _statsSubscription?.cancel();
      _monitor.stopMonitoring();
    });

    // 启动监控
    _startMonitoring();

    return MemoryPressureState.initial();
  }

  /// 开始内存监控
  void _startMonitoring() {
    AppLogger.i('Starting memory pressure monitoring in provider', 'MemoryPressureProvider');

    // 订阅压力变化事件
    _pressureSubscription = _monitor.onPressureChange.listen(
      _handlePressureEvent,
      onError: (Object e) {
        AppLogger.e('Memory pressure stream error', e, null, 'MemoryPressureProvider');
      },
    );

    // 订阅统计信息更新
    _statsSubscription = _monitor.onStatsUpdate.listen(
      _handleStatsUpdate,
      onError: (Object e) {
        AppLogger.e('Memory stats stream error', e, null, 'MemoryPressureProvider');
      },
    );

    // 启动监控（5秒采样间隔）
    _monitor.startMonitoring(sampleInterval: const Duration(seconds: 5));

    state = state.copyWith(isMonitoring: true);

    // 立即获取一次当前状态
    _updateCurrentState();
  }

  /// 处理压力事件
  void _handlePressureEvent(MemoryPressureEvent event) {
    AppLogger.i(
      'Memory pressure event: ${event.level.name} - ${event.reason ?? "unknown"}',
      'MemoryPressureProvider',
    );

    final recommendedLimit = _monitor.getRecommendedCacheLimit();

    state = state.copyWith(
      pressureLevel: event.level,
      lastEvent: event,
      recommendedCacheLimit: recommendedLimit,
    );

    // 根据压力等级自动执行清理
    switch (event.level) {
      case MemoryPressureLevel.nominal:
      // 正常状态，无需处理
      case MemoryPressureLevel.fair:
      // 轻微压力，可以延迟清理
        _scheduleCleanup();
      case MemoryPressureLevel.serious:
      // 中等压力，立即清理部分缓存
        _performCleanup(aggressive: false);
      case MemoryPressureLevel.critical:
      // 严重压力，立即清理所有缓存
        _performCleanup(aggressive: true);
    }
  }

  /// 处理统计信息更新
  void _handleStatsUpdate(MemoryStats stats) {
    final recommendedLimit = _monitor.getRecommendedCacheLimit();

    state = state.copyWith(
      stats: stats,
      pressureLevel: _monitor.currentLevel,
      recommendedCacheLimit: recommendedLimit,
    );
  }

  /// 更新当前状态
  void _updateCurrentState() {
    final stats = _monitor.getCurrentStats();
    final recommendedLimit = _monitor.getRecommendedCacheLimit();

    state = state.copyWith(
      stats: stats,
      pressureLevel: _monitor.currentLevel,
      recommendedCacheLimit: recommendedLimit,
      isMonitoring: _monitor.isMonitoring,
    );
  }

  /// 手动触发内存检查
  Future<void> checkMemory() async {
    AppLogger.d('Manual memory check triggered', 'MemoryPressureProvider');

    final event = _monitor.forceCheck();
    _updateCurrentState();

    if (event != null) {
      AppLogger.i(
        'Manual check found pressure: ${event.level.name}',
        'MemoryPressureProvider',
      );
    }
  }

  /// 手动清理缓存
  Future<void> cleanCache({bool aggressive = false}) async {
    if (state.isCleaning) return;

    await _performCleanup(aggressive: aggressive);
  }

  /// 执行缓存清理
  Future<void> _performCleanup({required bool aggressive}) async {
    if (_evictionService == null || state.isCleaning) return;

    state = state.copyWith(isCleaning: true);

    try {
      if (aggressive) {
        // 激进模式：清空所有缓存
        AppLogger.w('Performing aggressive cache cleanup', 'MemoryPressureProvider');
        _evictionService!.clear();
      } else {
        // 温和模式：淘汰部分条目
        final stats = _evictionService!.statistics;
        final entryCount = stats['entryCount'] as int? ?? 0;

        if (entryCount > 0) {
          // 淘汰20%的条目
          final evictCount = (entryCount * 0.2).ceil();
          AppLogger.i(
            'Performing cache cleanup: evicting $evictCount entries',
            'MemoryPressureProvider',
          );
          _evictionService!.evictByStrategy(EvictionStrategy.sizeFirst, evictCount);
        }
      }
    } catch (e, stack) {
      AppLogger.e('Cache cleanup failed', e, stack, 'MemoryPressureProvider');
    } finally {
      state = state.copyWith(isCleaning: false);
    }
  }

  /// 延迟清理（用于fair级别）
  void _scheduleCleanup() {
    // 延迟5秒后执行温和清理
    Future.delayed(const Duration(seconds: 5), () {
      if (state.pressureLevel == MemoryPressureLevel.fair) {
        _performCleanup(aggressive: false);
      }
    });
  }

  /// 停止监控
  void stopMonitoring() {
    AppLogger.i('Stopping memory pressure monitoring', 'MemoryPressureProvider');
    _monitor.stopMonitoring();
    state = state.copyWith(isMonitoring: false);
  }

  /// 重新开始监控
  void restartMonitoring() {
    if (state.isMonitoring) {
      stopMonitoring();
    }
    _startMonitoring();
  }

  /// 获取建议的最大缓存大小
  int? getRecommendedCacheLimit() {
    return _monitor.getRecommendedCacheLimit();
  }
}

/// 当前内存压力等级 Provider（简化版）
///
/// 用于只需要监听压力等级变化的场景
@riverpod
MemoryPressureLevel currentMemoryPressure(Ref ref) {
  final state = ref.watch(memoryPressureNotifierProvider);
  return state.pressureLevel;
}

/// 内存统计信息 Provider（简化版）
///
/// 用于只需要监听内存统计的场景
@riverpod
MemoryStats? memoryStats(Ref ref) {
  final state = ref.watch(memoryPressureNotifierProvider);
  return state.stats;
}

/// 是否处于高内存压力状态 Provider
///
/// 当压力等级为 serious 或 critical 时返回 true
@riverpod
bool isHighMemoryPressure(Ref ref) {
  final state = ref.watch(memoryPressureNotifierProvider);
  return state.pressureLevel == MemoryPressureLevel.serious ||
      state.pressureLevel == MemoryPressureLevel.critical;
}
