import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../data/services/image_metadata_service.dart';
import '../../data/services/metadata/metadata_cache_evictor.dart';
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
/// - 内存压力下释放 L1；L2 的容量淘汰由 [L2CacheCleaner] 负责
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

  /// 统计信息缓存有效期
  static const Duration _statisticsCacheValidity = Duration(seconds: 30);

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

  /// 清除 L1 内存缓存
  Future<void> clearL1MemoryCache() async {
    await ImageMetadataService().clearCache();
    GalleryDataSource().clearCache();
    _invalidateStatisticsCache();
    AppLogger.i('L1 memory cache cleared', 'GalleryCacheManager');
  }

  /// 使统计信息缓存失效（私有）
  void _invalidateStatisticsCache() {
    _cachedStatistics = null;
    _statisticsCacheTime = null;
  }

  /// 使统计信息缓存失效（公共接口）
  ///
  /// 当外部操作（如扫描新文件）修改了数据库后，调用此方法使统计缓存失效，
  /// 下次获取统计时将重新计算。
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
    final stats = await _computeStatistics();
    _cachedStatistics = stats;
    _statisticsCacheTime = DateTime.now();
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
    final persistentBox = imageService.persistentBox;
    final l2Bytes = persistentBox == null
        ? 0
        : await MetadataCacheEvictor.fileBytes(persistentBox);

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
    _invalidateStatisticsCache();
    AppLogger.i('Cache statistics reset', 'GalleryCacheManager');
  }
}

/// L2 Hive 缓存清理器
///
/// - 每 7 天压缩一次 box，回收覆盖和删除留下的失效帧
/// - 每小时最多检查一次 box 文件大小，超过阈值时按写入时间淘汰最旧条目，
///   降到目标水位后压缩
///
/// 调度时间记在 settings box，只属于本机，不参与云同步。
class L2CacheCleaner {
  L2CacheCleaner({
    Box<String>? Function()? cacheBox,
    Future<Box<dynamic>> Function()? settingsBox,
    DateTime Function()? clock,
    this.sizeThresholdBytes = _defaultSizeThresholdMB * _bytesPerMB,
    this.evictor = const MetadataCacheEvictor(),
  }) : _cacheBox = cacheBox ?? _metadataCacheBox,
       _settingsBox = settingsBox ?? _openSettingsBox,
       _clock = clock ?? DateTime.now;

  static const String _lastCleanupKey = 'l2_cache_last_cleanup';
  static const String _lastSizeCheckKey = 'l2_cache_last_size_check';
  static const Duration _cleanupInterval = Duration(days: 7);
  static const Duration _sizeCheckInterval = Duration(hours: 1);

  static const int _bytesPerMB = 1024 * 1024;
  static const int _defaultSizeThresholdMB = 500;
  // 留出余量，避免每次小幅增长都重新扫描并重写整个文件
  static const double _targetRatio = 0.8;

  final Box<String>? Function() _cacheBox;
  final Future<Box<dynamic>> Function() _settingsBox;
  final DateTime Function() _clock;

  /// box 文件超过该字节数时触发淘汰
  final int sizeThresholdBytes;
  final MetadataCacheEvictor evictor;

  /// 淘汰后的目标文件字节数
  int get targetBytes => (sizeThresholdBytes * _targetRatio).floor();

  /// 检查并执行清理
  Future<void> checkAndClean() async {
    try {
      final box = _availableCacheBox();
      if (box == null) return;
      final settings = await _settingsBox();
      final now = _clock();

      if (_isDue(settings, _lastCleanupKey, _cleanupInterval, now)) {
        await box.compact();
        await settings.put(_lastCleanupKey, '${now.millisecondsSinceEpoch}');
      }
      if (_isDue(settings, _lastSizeCheckKey, _sizeCheckInterval, now)) {
        await enforceSizeLimit();
        await settings.put(
          _lastSizeCheckKey,
          '${now.millisecondsSinceEpoch}',
        );
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to check L2 cache cleanup',
        e,
        stack,
        'L2CacheCleaner',
      );
    }
  }

  /// box 文件超过阈值时淘汰最旧条目；未超过阈值或缓存未就绪时返回 null
  Future<MetadataCacheEvictionResult?> enforceSizeLimit() async {
    final box = _availableCacheBox();
    if (box == null) return null;
    final bytes = await MetadataCacheEvictor.fileBytes(box);
    if (bytes <= sizeThresholdBytes) return null;

    final stopwatch = Stopwatch()..start();
    final result = await evictor.evictToTarget(box, targetBytes: targetBytes);
    AppLogger.i(
      'L2 cache evicted ${result.evictedEntries} of '
          '${result.scannedEntries} entries: '
          '${_formatMB(result.bytesBefore)} MB -> '
          '${_formatMB(result.bytesAfter)} MB (threshold '
          '${_formatMB(sizeThresholdBytes)} MB) in '
          '${stopwatch.elapsedMilliseconds} ms',
      'L2CacheCleaner',
    );
    return result;
  }

  Box<String>? _availableCacheBox() {
    final box = _cacheBox();
    if (box != null && box.isOpen) return box;
    AppLogger.w('Persistent box not available for cleanup', 'L2CacheCleaner');
    return null;
  }

  static bool _isDue(
    Box<dynamic> settings,
    String key,
    Duration interval,
    DateTime now,
  ) {
    final lastMillis = int.tryParse('${settings.get(key) ?? ''}');
    if (lastMillis == null) return true;
    final elapsed = now.difference(
      DateTime.fromMillisecondsSinceEpoch(lastMillis),
    );
    // 系统时间回拨后记录落在未来，不能因此长期不检查
    return elapsed.isNegative || elapsed >= interval;
  }

  static String _formatMB(int bytes) =>
      (bytes / _bytesPerMB).toStringAsFixed(1);

  static Box<String>? _metadataCacheBox() =>
      ImageMetadataService().persistentBox;

  static Future<Box<dynamic>> _openSettingsBox() async {
    if (Hive.isBoxOpen(StorageKeys.settingsBox)) {
      return Hive.box(StorageKeys.settingsBox);
    }
    return Hive.openBox(StorageKeys.settingsBox);
  }
}
