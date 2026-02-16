// 内存感知缓存配置

/// 缓存淘汰策略
enum EvictionPolicy {
  /// 最近最少使用
  lru('LRU', '最近最少使用'),

  /// 先进先出
  fifo('FIFO', '先进先出'),

  /// 最少使用
  lfu('LFU', '最少使用');

  final String code;
  final String displayName;

  const EvictionPolicy(this.code, this.displayName);

  /// 根据代码获取枚举值
  static EvictionPolicy fromCode(String code) {
    return EvictionPolicy.values.firstWhere(
      (e) => e.code == code,
      orElse: () => EvictionPolicy.lru,
    );
  }
}

/// 内存感知缓存配置类
///
/// 支持内存大小限制和对象数量限制，用于管理缓存的内存使用
class MemoryAwareCacheConfig {
  /// 最大内存限制（字节）
  final int maxMemoryBytes;

  /// 最大对象数量限制
  final int maxObjectCount;

  /// 缓存淘汰策略
  final EvictionPolicy evictionPolicy;

  /// 是否启用内存监控
  final bool enableMemoryMonitoring;

  /// 内存使用阈值（百分比，0-100），超过此阈值触发清理
  final int memoryThresholdPercentage;

  /// 自动清理间隔（毫秒），0表示不自动清理
  final int autoCleanupIntervalMs;

  /// 配置版本号
  final int version;

  const MemoryAwareCacheConfig({
    this.maxMemoryBytes = 100 * 1024 * 1024, // 默认 100MB
    this.maxObjectCount = 1000,
    this.evictionPolicy = EvictionPolicy.lru,
    this.enableMemoryMonitoring = true,
    this.memoryThresholdPercentage = 80,
    this.autoCleanupIntervalMs = 60000, // 默认 60 秒
    this.version = 1,
  });

  factory MemoryAwareCacheConfig.fromJson(Map<String, dynamic> json) {
    return MemoryAwareCacheConfig(
      maxMemoryBytes: json['maxMemoryBytes'] as int? ?? 100 * 1024 * 1024,
      maxObjectCount: json['maxObjectCount'] as int? ?? 1000,
      evictionPolicy:
          EvictionPolicy.fromCode(json['evictionPolicy'] as String? ?? 'LRU'),
      enableMemoryMonitoring: json['enableMemoryMonitoring'] as bool? ?? true,
      memoryThresholdPercentage:
          json['memoryThresholdPercentage'] as int? ?? 80,
      autoCleanupIntervalMs: json['autoCleanupIntervalMs'] as int? ?? 60000,
      version: json['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'maxMemoryBytes': maxMemoryBytes,
        'maxObjectCount': maxObjectCount,
        'evictionPolicy': evictionPolicy.code,
        'enableMemoryMonitoring': enableMemoryMonitoring,
        'memoryThresholdPercentage': memoryThresholdPercentage,
        'autoCleanupIntervalMs': autoCleanupIntervalMs,
        'version': version,
      };

  MemoryAwareCacheConfig copyWith({
    int? maxMemoryBytes,
    int? maxObjectCount,
    EvictionPolicy? evictionPolicy,
    bool? enableMemoryMonitoring,
    int? memoryThresholdPercentage,
    int? autoCleanupIntervalMs,
    int? version,
  }) {
    return MemoryAwareCacheConfig(
      maxMemoryBytes: maxMemoryBytes ?? this.maxMemoryBytes,
      maxObjectCount: maxObjectCount ?? this.maxObjectCount,
      evictionPolicy: evictionPolicy ?? this.evictionPolicy,
      enableMemoryMonitoring:
          enableMemoryMonitoring ?? this.enableMemoryMonitoring,
      memoryThresholdPercentage:
          memoryThresholdPercentage ?? this.memoryThresholdPercentage,
      autoCleanupIntervalMs:
          autoCleanupIntervalMs ?? this.autoCleanupIntervalMs,
      version: version ?? this.version,
    );
  }

  /// 获取最大内存限制（MB）
  int get maxMemoryMB => maxMemoryBytes ~/ (1024 * 1024);

  /// 检查当前内存使用量是否超过阈值
  bool isOverThreshold(int currentMemoryBytes) {
    final percentage = (currentMemoryBytes / maxMemoryBytes) * 100;
    return percentage >= memoryThresholdPercentage;
  }

  /// 检查对象数量是否超过限制
  bool isObjectCountExceeded(int currentCount) {
    return currentCount >= maxObjectCount;
  }

  /// 获取内存使用百分比
  double getMemoryUsagePercentage(int currentMemoryBytes) {
    return (currentMemoryBytes / maxMemoryBytes) * 100;
  }

  /// 创建保守配置（低内存占用）
  static MemoryAwareCacheConfig conservative() {
    return const MemoryAwareCacheConfig(
      maxMemoryBytes: 50 * 1024 * 1024, // 50MB
      maxObjectCount: 500,
      memoryThresholdPercentage: 70,
    );
  }

  /// 创建宽松配置（高内存占用）
  static MemoryAwareCacheConfig generous() {
    return const MemoryAwareCacheConfig(
      maxMemoryBytes: 500 * 1024 * 1024, // 500MB
      maxObjectCount: 5000,
      memoryThresholdPercentage: 90,
    );
  }

  @override
  String toString() {
    return 'MemoryAwareCacheConfig('
        'maxMemory: ${maxMemoryMB}MB, '
        'maxObjects: $maxObjectCount, '
        'policy: ${evictionPolicy.code}, '
        'threshold: $memoryThresholdPercentage%)';
  }
}
