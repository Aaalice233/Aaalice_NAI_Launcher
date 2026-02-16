import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/cache/memory_aware_cache_config.dart';
import '../../core/cache/memory_aware_cache_manager.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';

part 'cache_settings_provider.g.dart';

/// 缓存设置状态
///
/// 管理图片缓存的配置选项和统计信息
class CacheSettingsState {
  /// 最大内存限制（字节）
  final int maxMemoryBytes;

  /// 最大对象数量限制
  final int maxObjectCount;

  /// 缓存淘汰策略
  final EvictionPolicy evictionPolicy;

  /// 是否启用内存监控
  final bool enableMemoryMonitoring;

  /// 内存使用阈值（百分比，0-100）
  final int memoryThresholdPercentage;

  /// 自动清理间隔（毫秒）
  final int autoCleanupIntervalMs;

  /// 是否正在加载
  final bool isLoading;

  /// 错误信息
  final String? error;

  const CacheSettingsState({
    this.maxMemoryBytes = 100 * 1024 * 1024, // 默认 100MB
    this.maxObjectCount = 1000,
    this.evictionPolicy = EvictionPolicy.lru,
    this.enableMemoryMonitoring = true,
    this.memoryThresholdPercentage = 80,
    this.autoCleanupIntervalMs = 60000, // 默认 60 秒
    this.isLoading = false,
    this.error,
  });

  CacheSettingsState copyWith({
    int? maxMemoryBytes,
    int? maxObjectCount,
    EvictionPolicy? evictionPolicy,
    bool? enableMemoryMonitoring,
    int? memoryThresholdPercentage,
    int? autoCleanupIntervalMs,
    bool? isLoading,
    String? error,
  }) {
    return CacheSettingsState(
      maxMemoryBytes: maxMemoryBytes ?? this.maxMemoryBytes,
      maxObjectCount: maxObjectCount ?? this.maxObjectCount,
      evictionPolicy: evictionPolicy ?? this.evictionPolicy,
      enableMemoryMonitoring:
          enableMemoryMonitoring ?? this.enableMemoryMonitoring,
      memoryThresholdPercentage:
          memoryThresholdPercentage ?? this.memoryThresholdPercentage,
      autoCleanupIntervalMs:
          autoCleanupIntervalMs ?? this.autoCleanupIntervalMs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 获取最大内存限制（MB）
  int get maxMemoryMB => maxMemoryBytes ~/ (1024 * 1024);

  /// 创建配置对象
  MemoryAwareCacheConfig toConfig() {
    return MemoryAwareCacheConfig(
      maxMemoryBytes: maxMemoryBytes,
      maxObjectCount: maxObjectCount,
      evictionPolicy: evictionPolicy,
      enableMemoryMonitoring: enableMemoryMonitoring,
      memoryThresholdPercentage: memoryThresholdPercentage,
      autoCleanupIntervalMs: autoCleanupIntervalMs,
    );
  }

  /// 从配置对象创建状态
  factory CacheSettingsState.fromConfig(MemoryAwareCacheConfig config) {
    return CacheSettingsState(
      maxMemoryBytes: config.maxMemoryBytes,
      maxObjectCount: config.maxObjectCount,
      evictionPolicy: config.evictionPolicy,
      enableMemoryMonitoring: config.enableMemoryMonitoring,
      memoryThresholdPercentage: config.memoryThresholdPercentage,
      autoCleanupIntervalMs: config.autoCleanupIntervalMs,
    );
  }
}

/// 缓存设置 Notifier
///
/// 管理图片缓存设置的加载、更新和持久化
@Riverpod(keepAlive: true)
class CacheSettingsNotifier extends _$CacheSettingsNotifier {
  @override
  CacheSettingsState build() {
    // 异步加载设置
    _loadSettings();
    return const CacheSettingsState(isLoading: true);
  }

  /// 从存储加载设置
  Future<void> _loadSettings() async {
    try {
      final storage = ref.read(localStorageServiceProvider);

      final maxMemoryBytes = storage.getSetting<int>(
        StorageKeys.imageCacheMaxMemoryBytes,
        defaultValue: 100 * 1024 * 1024,
      );

      final maxObjectCount = storage.getSetting<int>(
        StorageKeys.imageCacheMaxObjectCount,
        defaultValue: 1000,
      );

      final evictionPolicyCode = storage.getSetting<String>(
        StorageKeys.imageCacheEvictionPolicy,
        defaultValue: 'LRU',
      );

      final enableMemoryMonitoring = storage.getSetting<bool>(
        StorageKeys.imageCacheEnableMemoryMonitoring,
        defaultValue: true,
      );

      final memoryThresholdPercentage = storage.getSetting<int>(
        StorageKeys.imageCacheMemoryThresholdPercentage,
        defaultValue: 80,
      );

      final autoCleanupIntervalMs = storage.getSetting<int>(
        StorageKeys.imageCacheAutoCleanupIntervalMs,
        defaultValue: 60000,
      );

      state = CacheSettingsState(
        maxMemoryBytes: maxMemoryBytes ?? 100 * 1024 * 1024,
        maxObjectCount: maxObjectCount ?? 1000,
        evictionPolicy: EvictionPolicy.fromCode(evictionPolicyCode ?? 'LRU'),
        enableMemoryMonitoring: enableMemoryMonitoring ?? true,
        memoryThresholdPercentage: memoryThresholdPercentage ?? 80,
        autoCleanupIntervalMs: autoCleanupIntervalMs ?? 60000,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载缓存设置失败: $e',
      );
    }
  }

  /// 设置最大内存限制
  Future<void> setMaxMemoryMB(int mb) async {
    final bytes = mb * 1024 * 1024;
    state = state.copyWith(maxMemoryBytes: bytes);
    await _persistSettings();
  }

  /// 设置最大对象数量
  Future<void> setMaxObjectCount(int count) async {
    state = state.copyWith(maxObjectCount: count);
    await _persistSettings();
  }

  /// 设置淘汰策略
  Future<void> setEvictionPolicy(EvictionPolicy policy) async {
    state = state.copyWith(evictionPolicy: policy);
    await _persistSettings();
  }

  /// 设置是否启用内存监控
  Future<void> setEnableMemoryMonitoring(bool enable) async {
    state = state.copyWith(enableMemoryMonitoring: enable);
    await _persistSettings();
  }

  /// 设置内存阈值百分比
  Future<void> setMemoryThresholdPercentage(int percentage) async {
    state = state.copyWith(
      memoryThresholdPercentage: percentage.clamp(1, 100),
    );
    await _persistSettings();
  }

  /// 设置自动清理间隔（毫秒）
  Future<void> setAutoCleanupIntervalMs(int ms) async {
    state = state.copyWith(autoCleanupIntervalMs: ms);
    await _persistSettings();
  }

  /// 保存设置到存储
  Future<void> _persistSettings() async {
    try {
      final storage = ref.read(localStorageServiceProvider);

      await storage.setSetting(
        StorageKeys.imageCacheMaxMemoryBytes,
        state.maxMemoryBytes,
      );
      await storage.setSetting(
        StorageKeys.imageCacheMaxObjectCount,
        state.maxObjectCount,
      );
      await storage.setSetting(
        StorageKeys.imageCacheEvictionPolicy,
        state.evictionPolicy.code,
      );
      await storage.setSetting(
        StorageKeys.imageCacheEnableMemoryMonitoring,
        state.enableMemoryMonitoring,
      );
      await storage.setSetting(
        StorageKeys.imageCacheMemoryThresholdPercentage,
        state.memoryThresholdPercentage,
      );
      await storage.setSetting(
        StorageKeys.imageCacheAutoCleanupIntervalMs,
        state.autoCleanupIntervalMs,
      );
    } catch (e) {
      state = state.copyWith(error: '保存缓存设置失败: $e');
    }
  }

  /// 重置为默认设置
  Future<void> resetToDefaults() async {
    state = const CacheSettingsState(isLoading: false);
    await _persistSettings();
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// 缓存统计信息状态
class CacheStatisticsState {
  /// 当前内存使用量（字节）
  final int currentMemoryBytes;

  /// 对象数量
  final int objectCount;

  /// 缓存命中次数
  final int hitCount;

  /// 缓存未命中次数
  final int missCount;

  /// 淘汰次数
  final int evictionCount;

  const CacheStatisticsState({
    this.currentMemoryBytes = 0,
    this.objectCount = 0,
    this.hitCount = 0,
    this.missCount = 0,
    this.evictionCount = 0,
  });

  /// 获取当前内存使用量（MB）
  double get currentMemoryMB => currentMemoryBytes / (1024 * 1024);

  /// 获取命中率
  double get hitRate {
    final total = hitCount + missCount;
    return total == 0 ? 0.0 : hitCount / total;
  }

  CacheStatisticsState copyWith({
    int? currentMemoryBytes,
    int? objectCount,
    int? hitCount,
    int? missCount,
    int? evictionCount,
  }) {
    return CacheStatisticsState(
      currentMemoryBytes: currentMemoryBytes ?? this.currentMemoryBytes,
      objectCount: objectCount ?? this.objectCount,
      hitCount: hitCount ?? this.hitCount,
      missCount: missCount ?? this.missCount,
      evictionCount: evictionCount ?? this.evictionCount,
    );
  }
}

/// 缓存统计信息 Provider
@Riverpod(keepAlive: true)
class CacheStatisticsNotifier extends _$CacheStatisticsNotifier {
  @override
  CacheStatisticsState build() {
    // 初始加载统计信息
    _refreshStatistics();
    return const CacheStatisticsState();
  }

  /// 刷新缓存统计信息
  Future<void> _refreshStatistics() async {
    try {
      final manager = MemoryAwareCacheManager.instance;
      final stats = manager.statistics;

      state = CacheStatisticsState(
        currentMemoryBytes: stats['memoryBytes'] as int? ?? 0,
        objectCount: stats['objectCount'] as int? ?? 0,
        hitCount: stats['hitCount'] as int? ?? 0,
        missCount: stats['missCount'] as int? ?? 0,
        evictionCount: stats['evictionCount'] as int? ?? 0,
      );
    } catch (e) {
      // 静默失败，保持现有状态
    }
  }

  /// 手动刷新统计信息
  Future<void> refresh() async {
    await _refreshStatistics();
  }

  /// 清除缓存并刷新统计
  Future<void> clearCache() async {
    try {
      final manager = MemoryAwareCacheManager.instance;
      await manager.emptyCache();
      manager.clearTracking();
      await _refreshStatistics();
    } catch (e) {
      // 静默失败
    }
  }

  /// 重置统计信息
  void resetStatistics() {
    MemoryAwareCacheManager.instance.resetStatistics();
    state = const CacheStatisticsState();
  }
}
