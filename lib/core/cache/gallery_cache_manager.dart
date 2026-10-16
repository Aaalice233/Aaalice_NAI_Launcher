import 'package:flutter/material.dart';

import '../../core/utils/app_logger.dart';
import '../../data/services/image_metadata_service.dart';
import '../database/datasources/gallery_data_source.dart';

/// 缓存统计信息
class CacheStatistics {
  /// L1 内存缓存大小（条目数）
  final int l1MemorySize;

  /// L1 内存缓存命中率（0.0 - 1.0）
  final double l1HitRate;

  /// L1 内存缓存占用（估算字节数）
  final int l1MemoryBytes;

  /// L2 Hive 缓存大小（条目数）
  final int l2HiveSize;

  /// L2 Hive 缓存命中率（0.0 - 1.0）
  final double l2HitRate;

  /// L2 Hive 缓存占用（字节数）
  final int l2HiveBytes;

  /// L3 数据库图片记录数
  final int l3DatabaseImageCount;

  /// L3 数据库元数据记录数
  final int l3DatabaseMetadataCount;

  /// 总缓存命中率（加权平均）
  final double totalHitRate;

  /// 最后更新时间
  final DateTime lastUpdated;

  const CacheStatistics({
    required this.l1MemorySize,
    required this.l1HitRate,
    required this.l1MemoryBytes,
    required this.l2HiveSize,
    required this.l2HitRate,
    required this.l2HiveBytes,
    required this.l3DatabaseImageCount,
    required this.l3DatabaseMetadataCount,
    required this.totalHitRate,
    required this.lastUpdated,
  });

  /// 获取总缓存大小（字节数）
  int get totalBytes => l1MemoryBytes + l2HiveBytes;

  @override
  String toString() =>
      'CacheStatistics(L1: $l1MemorySize entries, ${(l1HitRate * 100).toStringAsFixed(1)}% hit, ${_formatBytes(l1MemoryBytes)}, '
      'L2: $l2HiveSize entries, ${(l2HitRate * 100).toStringAsFixed(1)}% hit, ${_formatBytes(l2HiveBytes)}, '
      'DB: $l3DatabaseImageCount images, $l3DatabaseMetadataCount metadata, '
      'Total: ${(totalHitRate * 100).toStringAsFixed(1)}% hit, ${_formatBytes(totalBytes)})';

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

/// 画廊缓存管理器
///
/// 提供统一接口管理三层缓存：
/// - L1: 内存缓存 (ImageMetadataService._memoryCache)
/// - L2: Hive 缓存 (ImageMetadataService._persistentBox)
/// - L3: SQLite 数据库 (GalleryDataSource)
///
/// 特性：
/// - 缓存统计（L1 按实际条目估算字节数，L2 读取 box 文件大小）
/// - 内存压力下释放 L1；L2 的容量淘汰由 L2CacheCleaner 负责
class GalleryCacheManager {
  static final GalleryCacheManager _instance = GalleryCacheManager._internal();
  factory GalleryCacheManager() => _instance;
  GalleryCacheManager._internal();

  /// 统计信息刷新回调列表
  final List<VoidCallback> _onStatisticsInvalidatedCallbacks = [];

  /// 缓存统计信息缓存
  CacheStatistics? _cachedStatistics;

  /// 统计信息缓存时间
  DateTime? _statisticsCacheTime;

  /// 每次失效加一，计算期间发生失效的结果不写回缓存
  int _statisticsGeneration = 0;

  Future<CacheStatistics> Function()? _statisticsComputerOverride;

  /// 统计信息缓存有效期
  static const Duration _statisticsCacheValidity = Duration(seconds: 30);

  /// 传 null 恢复真实统计，同时清空统计缓存
  @visibleForTesting
  void debugSetStatisticsComputerForTesting(
    Future<CacheStatistics> Function()? computer,
  ) {
    _statisticsComputerOverride = computer;
    _invalidateStatisticsCache();
  }

  @visibleForTesting
  int get debugStatisticsListenerCount =>
      _onStatisticsInvalidatedCallbacks.length;

  /// 注册统计信息刷新回调
  ///
  /// 当统计信息缓存失效时，会通知所有注册的监听者（如设置页面的统计组件）。
  void registerOnStatisticsInvalidated(VoidCallback callback) {
    _onStatisticsInvalidatedCallbacks.add(callback);
  }

  /// 注销统计信息刷新回调
  void unregisterOnStatisticsInvalidated(VoidCallback callback) {
    _onStatisticsInvalidatedCallbacks.remove(callback);
  }

  /// 通知统计信息已失效
  void _notifyStatisticsInvalidated() {
    for (final callback in _onStatisticsInvalidatedCallbacks.toList()) {
      try {
        callback();
      } catch (e) {
        AppLogger.w(
          'Statistics invalidation callback failed: $e',
          'GalleryCacheManager',
        );
      }
    }
  }

  /// 清除 L1 内存缓存与路径哈希、图库查询的内存缓存；L2 保持不动
  Future<void> clearL1MemoryCache() async {
    ImageMetadataService().clearMemoryCache();
    GalleryDataSource().clearCache();
    _invalidateStatisticsCache();
    AppLogger.i('L1 memory cache cleared', 'GalleryCacheManager');
  }

  /// 使统计信息缓存失效（私有）
  void _invalidateStatisticsCache() {
    _statisticsGeneration++;
    _cachedStatistics = null;
    _statisticsCacheTime = null;
  }

  /// 使统计信息缓存失效（公共接口）
  ///
  /// 图库索引的一轮写入（扫描、收录、删除）完成后调用一次，不要逐文件调用；
  /// 设置页“立即刷新”也走这里，以绕过 30 秒缓存。
  /// 同时通知统计信息监听者（如设置页面的统计组件）立即刷新。
  void invalidateStatistics() {
    _invalidateStatisticsCache();
    _notifyStatisticsInvalidated(); // 通知设置页面的统计组件刷新
    AppLogger.d(
      'Cache statistics invalidated and notified',
      'GalleryCacheManager',
    );
  }

  /// 获取缓存统计（带缓存）
  Future<CacheStatistics> getStatistics() async {
    // 检查缓存是否有效
    if (_cachedStatistics != null &&
        _statisticsCacheTime != null &&
        DateTime.now().difference(_statisticsCacheTime!) <
            _statisticsCacheValidity) {
      return _cachedStatistics!;
    }

    // 重新计算统计信息
    final generation = _statisticsGeneration;
    final stats = await (_statisticsComputerOverride ?? _computeStatistics)();
    if (generation == _statisticsGeneration) {
      _cachedStatistics = stats;
      _statisticsCacheTime = DateTime.now();
    }
    return stats;
  }

  /// 计算缓存统计
  Future<CacheStatistics> _computeStatistics() async {
    final imageService = ImageMetadataService();
    final dataSource = GalleryDataSource();

    // 获取 L1 缓存统计
    final l1Size = imageService.memoryCacheSize;
    final l1HitRate = imageService.memoryCacheHitRate;
    final l1Bytes = imageService.memoryCacheEstimatedBytes;

    // 获取 L2 缓存统计
    final l2Size = await imageService.persistentCacheSize;
    final l2HitRate = imageService.persistentCacheHitRate;
    final l2Bytes = await imageService.persistentCacheFileBytes;

    // 获取 L3 数据库统计
    final imageCount = await dataSource.countImages();
    final metadataCount = await _getMetadataCount(dataSource);

    // 计算总命中率（加权平均）
    final totalRequests = (l1HitRate > 0 ? l1Size / l1HitRate : 0) +
        (l2HitRate > 0 ? l2Size / l2HitRate : 0);
    final totalHits = l1Size + l2Size;
    final totalHitRate = totalRequests > 0 ? totalHits / totalRequests : 0.0;

    return CacheStatistics(
      l1MemorySize: l1Size,
      l1HitRate: l1HitRate,
      l1MemoryBytes: l1Bytes,
      l2HiveSize: l2Size,
      l2HitRate: l2HitRate,
      l2HiveBytes: l2Bytes,
      l3DatabaseImageCount: imageCount,
      l3DatabaseMetadataCount: metadataCount,
      totalHitRate: totalHitRate.isFinite ? totalHitRate : 0.0,
      lastUpdated: DateTime.now(),
    );
  }

  Future<int> _getMetadataCount(GalleryDataSource dataSource) async {
    try {
      final health = await dataSource.checkHealth();
      return health.details['metadataCount'] as int? ?? 0;
    } catch (e) {
      AppLogger.w('Failed to get metadata count: $e', 'GalleryCacheManager');
      return 0;
    }
  }

  /// 重置所有缓存统计计数器
  Future<void> resetStatistics() async {
    ImageMetadataService().resetStatistics();
    invalidateStatistics();
    AppLogger.i('Cache statistics reset', 'GalleryCacheManager');
  }
}
