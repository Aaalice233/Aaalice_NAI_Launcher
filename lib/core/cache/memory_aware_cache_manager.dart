import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/app_logger.dart';
import 'memory_aware_cache_config.dart';

/// MemoryAwareCacheManager
///
/// A wrapper around flutter_cache_manager that adds memory monitoring capabilities.
/// This manager tracks cache statistics and provides memory-aware eviction policies.
///
/// 包装 flutter_cache_manager 并添加内存监控功能的缓存管理器。
/// 跟踪缓存统计信息并提供内存感知的淘汰策略。
class MemoryAwareCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'memoryAwareCache';

  final MemoryAwareCacheConfig _config;
  final Map<String, int> _objectSizeMap = {};
  int _currentMemoryBytes = 0;
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;
  Timer? _cleanupTimer;

  static final MemoryAwareCacheManager _instance =
      MemoryAwareCacheManager._internal();

  /// Factory constructor returning the singleton instance
  /// 工厂构造函数返回单例实例
  factory MemoryAwareCacheManager() => _instance;

  /// Private constructor with default config
  MemoryAwareCacheManager._internal()
      : _config = const MemoryAwareCacheConfig(),
        super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 1000,
          ),
        ) {
    _initializeMonitoring();
  }

  /// Constructor with custom configuration
  /// 使用自定义配置的构造函数
  MemoryAwareCacheManager.withConfig(this._config)
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: _config.maxObjectCount,
          ),
        ) {
    _initializeMonitoring();
  }

  /// Get the singleton instance
  /// 获取单例实例
  static MemoryAwareCacheManager get instance => _instance;

  /// Initialize memory monitoring
  /// 初始化内存监控
  void _initializeMonitoring() {
    if (_config.enableMemoryMonitoring && _config.autoCleanupIntervalMs > 0) {
      _cleanupTimer = Timer.periodic(
        Duration(milliseconds: _config.autoCleanupIntervalMs),
        (_) => _performMemoryCleanup(),
      );
      AppLogger.i(
        'Memory monitoring initialized: cleanup interval ${_config.autoCleanupIntervalMs}ms',
        'MemoryAwareCacheManager',
      );
    }
  }

  /// Get current configuration
  /// 获取当前配置
  MemoryAwareCacheConfig get config => _config;

  /// Get current memory usage in bytes
  /// 获取当前内存使用量（字节）
  int get currentMemoryBytes => _currentMemoryBytes;

  /// Get current memory usage in MB
  /// 获取当前内存使用量（MB）
  double get currentMemoryMB => _currentMemoryBytes / (1024 * 1024);

  /// Get memory usage percentage
  /// 获取内存使用百分比
  double get memoryUsagePercentage {
    return (_currentMemoryBytes / _config.maxMemoryBytes) * 100;
  }

  /// Check if memory is over threshold
  /// 检查内存是否超过阈值
  bool get isOverThreshold {
    return _config.isOverThreshold(_currentMemoryBytes);
  }

  /// Get cache statistics
  /// 获取缓存统计信息
  Map<String, dynamic> get statistics => {
        'memoryBytes': _currentMemoryBytes,
        'memoryMB': currentMemoryMB.toStringAsFixed(2),
        'memoryUsagePercentage': memoryUsagePercentage.toStringAsFixed(2),
        'maxMemoryMB': _config.maxMemoryMB,
        'objectCount': _objectSizeMap.length,
        'maxObjectCount': _config.maxObjectCount,
        'hitCount': _hitCount,
        'missCount': _missCount,
        'evictionCount': _evictionCount,
        'hitRate': hitRate.toStringAsFixed(4),
        'isOverThreshold': isOverThreshold,
        'thresholdPercentage': _config.memoryThresholdPercentage,
      };

  /// Record a cache hit
  /// 记录缓存命中
  void recordHit() {
    _hitCount++;
    AppLogger.d(
      'Cache hit (total: $_hitCount, rate: ${(hitRate * 100).toStringAsFixed(2)}%)',
      'MemoryAwareCacheManager',
    );
  }

  /// Record a cache miss
  /// 记录缓存未命中
  void recordMiss() {
    _missCount++;
    AppLogger.d(
      'Cache miss (total: $_missCount, rate: ${((1 - hitRate) * 100).toStringAsFixed(2)}%)',
      'MemoryAwareCacheManager',
    );
  }

  /// Get cache hit rate (0.0 to 1.0)
  /// 获取缓存命中率（0.0 到 1.0）
  double get hitRate {
    final total = _hitCount + _missCount;
    return total == 0 ? 0.0 : _hitCount / total;
  }

  /// Track an object with its size
  /// 跟踪对象及其大小
  void trackObject(String key, int sizeInBytes) {
    // Remove old size if updating
    if (_objectSizeMap.containsKey(key)) {
      _currentMemoryBytes -= _objectSizeMap[key]!;
    }

    _objectSizeMap[key] = sizeInBytes;
    _currentMemoryBytes += sizeInBytes;

    AppLogger.d(
      'Tracked object: $key (${(sizeInBytes / 1024).toStringAsFixed(2)}KB), '
      'total memory: ${currentMemoryMB.toStringAsFixed(2)}MB',
      'MemoryAwareCacheManager',
    );

    // Check if we need to evict
    if (_shouldEvict()) {
      _performMemoryCleanup();
    }
  }

  /// Untrack an object
  /// 取消跟踪对象
  void untrackObject(String key) {
    if (_objectSizeMap.containsKey(key)) {
      _currentMemoryBytes -= _objectSizeMap[key]!;
      _objectSizeMap.remove(key);
      AppLogger.d(
        'Untracked object: $key, remaining memory: ${currentMemoryMB.toStringAsFixed(2)}MB',
        'MemoryAwareCacheManager',
      );
    }
  }

  /// Check if eviction is needed based on memory or object count
  /// 根据内存或对象数量检查是否需要淘汰
  bool _shouldEvict() {
    return _config.isOverThreshold(_currentMemoryBytes) ||
        _config.isObjectCountExceeded(_objectSizeMap.length);
  }

  /// Perform memory cleanup based on eviction policy
  /// 根据淘汰策略执行内存清理
  Future<void> _performMemoryCleanup() async {
    if (!isOverThreshold && !_config.isObjectCountExceeded(_objectSizeMap.length)) {
      return;
    }

    AppLogger.i(
      'Starting memory cleanup: ${currentMemoryMB.toStringAsFixed(2)}MB used, '
      '${_objectSizeMap.length} objects',
      'MemoryAwareCacheManager',
    );

    final targetBytes = (_config.maxMemoryBytes * _config.memoryThresholdPercentage / 100).toInt();
    int evictedCount = 0;
    int evictedBytes = 0;

    while ((_currentMemoryBytes > targetBytes ||
            _config.isObjectCountExceeded(_objectSizeMap.length)) &&
        _objectSizeMap.isNotEmpty) {
      final keyToEvict = _selectKeyToEvict();
      if (keyToEvict == null) break;

      final size = _objectSizeMap[keyToEvict] ?? 0;
      _objectSizeMap.remove(keyToEvict);
      _currentMemoryBytes -= size;
      evictedBytes += size;
      evictedCount++;

      // Also remove from underlying cache
      await removeFile(keyToEvict);
    }

    _evictionCount += evictedCount;

    AppLogger.i(
      'Memory cleanup completed: evicted $evictedCount objects (${(evictedBytes / (1024 * 1024)).toStringAsFixed(2)}MB), '
      'remaining: ${currentMemoryMB.toStringAsFixed(2)}MB',
      'MemoryAwareCacheManager',
    );
  }

  /// Select key to evict based on eviction policy
  /// 根据淘汰策略选择要淘汰的键
  String? _selectKeyToEvict() {
    if (_objectSizeMap.isEmpty) return null;

    switch (_config.evictionPolicy) {
      case EvictionPolicy.lru:
      case EvictionPolicy.fifo:
        // For LRU/FIFO, evict the first entry (oldest)
        return _objectSizeMap.keys.first;
      case EvictionPolicy.lfu:
        // For LFU, we would need access frequency tracking
        // For simplicity, fall back to LRU
        return _objectSizeMap.keys.first;
    }
  }

  /// Get estimated size of an object in cache
  /// 获取缓存中对象的估计大小
  int? getObjectSize(String key) {
    return _objectSizeMap[key];
  }

  /// Check if an object is being tracked
  /// 检查对象是否被跟踪
  bool isTracking(String key) {
    return _objectSizeMap.containsKey(key);
  }

  /// Get the number of tracked objects
  /// 获取跟踪的对象数量
  int get trackedObjectCount => _objectSizeMap.length;

  /// Reset all statistics
  /// 重置所有统计信息
  void resetStatistics() {
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
    AppLogger.i(
      'Statistics reset',
      'MemoryAwareCacheManager',
    );
  }

  /// Clear all tracked objects and reset memory tracking
  /// 清除所有跟踪的对象并重置内存跟踪
  void clearTracking() {
    _objectSizeMap.clear();
    _currentMemoryBytes = 0;
    AppLogger.i(
      'Memory tracking cleared',
      'MemoryAwareCacheManager',
    );
  }

  /// Dispose and cleanup resources
  /// 释放资源并清理
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    AppLogger.i(
      'MemoryAwareCacheManager disposed',
      'MemoryAwareCacheManager',
    );
  }

  /// Force immediate memory cleanup
  /// 强制立即执行内存清理
  Future<void> forceCleanup() async {
    AppLogger.i(
      'Force cleanup triggered',
      'MemoryAwareCacheManager',
    );
    await _performMemoryCleanup();
  }
}
