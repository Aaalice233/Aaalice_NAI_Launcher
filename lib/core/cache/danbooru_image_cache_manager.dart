import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/app_logger.dart';
import 'memory_aware_cache_config.dart';
import 'memory_aware_cache_manager.dart';

/// Danbooru 图片缓存管理器
///
/// 基于 MemoryAwareCacheManager 的图片缓存管理器，
/// 使用自定义配置提升图片加载性能：
/// - 最大缓存对象数：1000（支持大量图片）
/// - 过期时间：7天
/// - 支持 HTTP/2（通过全局 Dio 实例）
/// - 内存感知：自动监控和清理，防止 OOM
///
/// 包装 MemoryAwareCacheManager 并添加 Danbooru 特定的图片缓存功能。
class DanbooruImageCacheManager implements ImageCacheManager {
  static const key = 'danbooruImageCache';

  final MemoryAwareCacheManager _cacheManager;

  static final DanbooruImageCacheManager _instance =
      DanbooruImageCacheManager._internal();

  /// 工厂构造函数返回单例实例
  factory DanbooruImageCacheManager() => _instance;

  /// 私有构造函数，使用内存感知缓存配置
  DanbooruImageCacheManager._internal()
      : _cacheManager = MemoryAwareCacheManager.withConfig(
          const MemoryAwareCacheConfig(
            maxMemoryBytes: 200 * 1024 * 1024, // Danbooru 图片较多，使用 200MB
            maxObjectCount: 1000,
            evictionPolicy: EvictionPolicy.lru,
            enableMemoryMonitoring: true,
            memoryThresholdPercentage: 80,
            autoCleanupIntervalMs: 60000, // 60秒自动清理
          ),
        ) {
    AppLogger.i(
      'DanbooruImageCacheManager initialized with memory-aware config',
      'DanbooruImageCacheManager',
    );
  }

  /// 使用自定义配置的构造函数
  DanbooruImageCacheManager.withConfig(MemoryAwareCacheConfig config)
      : _cacheManager = MemoryAwareCacheManager.withConfig(config) {
    AppLogger.i(
      'DanbooruImageCacheManager initialized with custom config: $config',
      'DanbooruImageCacheManager',
    );
  }

  /// 获取单例实例
  static DanbooruImageCacheManager get instance => _instance;

  /// 获取底层的 MemoryAwareCacheManager
  MemoryAwareCacheManager get cacheManager => _cacheManager;

  /// 使用用户存储的配置初始化缓存管理器
  ///
  /// 从 [CacheSettingsNotifier] 加载配置并应用，确保缓存限制符合用户设置。
  /// 由于底层缓存管理器是单例，此方法主要用于触发清理和记录当前配置。
  Future<void> initializeFromSettings() async {
    // 触发一次强制清理以确保配置立即生效
    await forceCleanup();
    AppLogger.i(
      'DanbooruImageCacheManager initialized from settings, '
      'current memory: ${currentMemoryMB.toStringAsFixed(2)}MB',
      'DanbooruImageCacheManager',
    );
  }

  /// 获取当前内存使用量（字节）
  int get currentMemoryBytes => _cacheManager.currentMemoryBytes;

  /// 获取当前内存使用量（MB）
  double get currentMemoryMB => _cacheManager.currentMemoryMB;

  /// 获取内存使用百分比
  double get memoryUsagePercentage => _cacheManager.memoryUsagePercentage;

  /// 检查内存是否超过阈值
  bool get isOverThreshold => _cacheManager.isOverThreshold;

  /// 获取缓存统计信息
  Map<String, dynamic> get statistics => _cacheManager.statistics;

  /// 获取缓存命中率（0.0 到 1.0）
  double get hitRate => _cacheManager.hitRate;

  /// 记录缓存命中
  void recordHit() => _cacheManager.recordHit();

  /// 记录缓存未命中
  void recordMiss() => _cacheManager.recordMiss();

  /// 跟踪对象及其大小
  void trackObject(String key, int sizeInBytes) =>
      _cacheManager.trackObject(key, sizeInBytes);

  /// 取消跟踪对象
  void untrackObject(String key) => _cacheManager.untrackObject(key);

  /// 强制立即执行内存清理
  Future<void> forceCleanup() async {
    AppLogger.i(
      'Force cleanup triggered for Danbooru cache',
      'DanbooruImageCacheManager',
    );
    await _cacheManager.forceCleanup();
  }

  /// 重置所有统计信息
  void resetStatistics() => _cacheManager.resetStatistics();

  /// 清除所有跟踪的对象并重置内存跟踪
  void clearTracking() => _cacheManager.clearTracking();

  /// 释放资源并清理
  void dispose() {
    AppLogger.i(
      'DanbooruImageCacheManager disposed',
      'DanbooruImageCacheManager',
    );
    _cacheManager.dispose();
  }

  // 实现 ImageCacheManager 接口方法，委托给底层 cache manager

  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    try {
      final file = await _cacheManager.getSingleFile(url, key: key, headers: headers);
      _cacheManager.recordHit();
      return file;
    } catch (e) {
      _cacheManager.recordMiss();
      rethrow;
    }
  }

  @override
  Stream<FileResponse> getFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool? withProgress,
  }) {
    return _cacheManager.getFile(
      url,
      key: key,
      headers: headers,
      withProgress: withProgress,
    );
  }

  @override
  Future<FileInfo?> getFileFromCache(String key, {bool ignoreMemCache = false}) async {
    final info = await _cacheManager.getFileFromCache(key, ignoreMemCache: ignoreMemCache);
    if (info != null) {
      _cacheManager.recordHit();
    } else {
      _cacheManager.recordMiss();
    }
    return info;
  }

  @override
  Future<FileInfo?> getFileFromMemory(String key) async {
    final info = await _cacheManager.getFileFromMemory(key);
    if (info != null) {
      _cacheManager.recordHit();
    } else {
      _cacheManager.recordMiss();
    }
    return info;
  }

  @override
  Future<void> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    await _cacheManager.putFile(
      url,
      fileBytes,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    );
    // 跟踪文件大小
    _cacheManager.trackObject(key ?? url, fileBytes.length);
  }

  @override
  Future<void> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    // 收集流数据以计算大小
    final bytes = <int>[];
    await for (final chunk in source) {
      bytes.addAll(chunk);
    }
    final uint8List = Uint8List.fromList(bytes);

    await _cacheManager.putFile(
      url,
      uint8List,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    );
    _cacheManager.trackObject(key ?? url, uint8List.length);
  }

  @override
  Future<void> removeFile(String key) async {
    _cacheManager.untrackObject(key);
    await _cacheManager.removeFile(key);
  }

  @override
  Future<void> emptyCache() async {
    _cacheManager.clearTracking();
    await _cacheManager.emptyCache();
    AppLogger.i(
      'Danbooru cache emptied',
      'DanbooruImageCacheManager',
    );
  }
}
