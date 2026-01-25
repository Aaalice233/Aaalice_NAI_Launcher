import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/utils/app_logger.dart';

/// Image preloader service for next-screen thumbnail rendering
///
/// 图片预加载服务，用于预加载下一屏幕的缩略图
///
/// Improves perceived performance by preloading images before they are displayed.
/// Uses precacheImage to load images into the image cache in the background.
/// 通过在显示前预加载图片来提升感知性能。
/// 使用 precacheImage 在后台将图片加载到图片缓存中。
class ImagePreloaderService {
  ImagePreloaderService._() : maxConcurrentLoads = 3;

  /// Maximum number of images to preload concurrently
  /// 同时预加载的最大图片数量
  final int maxConcurrentLoads;

  /// Pending preload operations (can be cancelled)
  /// 待处理的预加载操作（可取消）
  final Map<String, Future<void>> _pendingPreloads = {};

  /// Statistics counters
  /// 统计计数器
  int _successCount = 0;
  int _failureCount = 0;
  int _cancelledCount = 0;

  /// Preload images for next-screen thumbnails
  ///
  /// [imagePaths] List of image file paths to preload
  /// [context] BuildContext required for precacheImage
  /// Returns the number of successfully preloaded images
  ///
  /// 预加载下一屏幕的缩略图
  ///
  /// [imagePaths] 要预加载的图片文件路径列表
  /// [context] precacheImage 所需的 BuildContext
  /// 返回成功预加载的图片数量
  Future<int> preloadImages(
    List<String> imagePaths,
    BuildContext context,
  ) async {
    if (imagePaths.isEmpty) {
      AppLogger.d('No images to preload', 'ImagePreloader');
      return 0;
    }

    final stopwatch = Stopwatch()..start();
    AppLogger.i(
      'Starting preload: ${imagePaths.length} images',
      'ImagePreloader',
    );

    // Filter out already pending or completed preloads
    // 过滤掉已在处理中或已完成的预加载
    final pathsToLoad = imagePaths.where((path) {
      return !_pendingPreloads.containsKey(path);
    }).toList();

    if (pathsToLoad.isEmpty) {
      AppLogger.d(
        'All images already pending preload',
        'ImagePreloader',
      );
      return 0;
    }

    // Process in batches to limit concurrent loads
    // 分批处理以限制并发加载数
    final batchSize = maxConcurrentLoads;
    final batches = <List<String>>[];
    for (int i = 0; i < pathsToLoad.length; i += batchSize) {
      final end = (i + batchSize < pathsToLoad.length)
          ? i + batchSize
          : pathsToLoad.length;
      batches.add(pathsToLoad.sublist(i, end));
    }

    int successCount = 0;

    // Process each batch sequentially
    // 顺序处理每个批次
    for (final batch in batches) {
      // Process all images in current batch concurrently
      // 并发处理当前批次的所有图片
      final results = await Future.wait(
        batch.map((path) => _preloadSingleImage(path, context)),
      );

      // Count successes
      successCount += results.where((success) => success).length;
    }

    stopwatch.stop();
    AppLogger.i(
      'Preload completed: $successCount/${pathsToLoad.length} images '
          'in ${stopwatch.elapsedMilliseconds}ms',
      'ImagePreloader',
    );

    return successCount;
  }

  /// Preload a single image
  ///
  /// Returns true if successful, false otherwise
  ///
  /// 预加载单个图片
  ///
  /// 成功返回 true，失败返回 false
  Future<bool> _preloadSingleImage(
    String imagePath,
    BuildContext context,
  ) async {
    try {
      // Check if file exists
      // 检查文件是否存在
      final file = File(imagePath);
      if (!file.existsSync()) {
        AppLogger.w(
          'Preload failed: file not found - $imagePath',
          'ImagePreloader',
        );
        _failureCount++;
        return false;
      }

      // Create the image provider
      // 创建图片 provider
      final provider = FileImage(file);

      // Store the future for potential cancellation
      // 存储 Future 以便可能的取消
      final preloadFuture = precacheImage(provider, context);

      _pendingPreloads[imagePath] = preloadFuture;

      // Wait for preload to complete
      // 等待预加载完成
      await preloadFuture;

      // Remove from pending map
      // 从待处理映射中移除
      _pendingPreloads.remove(imagePath);

      _successCount++;
      AppLogger.d(
        'Preloaded: $imagePath (success: $_successCount, failures: $_failureCount)',
        'ImagePreloader',
      );
      return true;
    } catch (e) {
      _pendingPreloads.remove(imagePath);
      _failureCount++;
      AppLogger.w(
        'Preload failed: $imagePath - $e',
        'ImagePreloader',
      );
      return false;
    }
  }

  /// Cancel pending preload operations
  ///
  /// [imagePaths] Optional list of specific image paths to cancel.
  /// If null, cancels all pending preloads.
  /// Returns the number of cancelled operations.
  ///
  /// 取消待处理的预加载操作
  ///
  /// [imagePaths] 要取消的特定图片路径列表（可选）。
  /// 如果为 null，则取消所有待处理的预加载。
  /// 返回取消的操作数量。
  int cancelPreload([List<String>? imagePaths]) {
    if (imagePaths == null) {
      // Cancel all pending preloads
      // 取消所有待处理的预加载
      final count = _pendingPreloads.length;
      _pendingPreloads.clear();
      _cancelledCount += count;

      if (count > 0) {
        AppLogger.i(
          'Cancelled all pending preloads: $count images',
          'ImagePreloader',
        );
      }

      return count;
    } else {
      // Cancel specific preloads
      // 取消特定的预加载
      int count = 0;
      for (final path in imagePaths) {
        if (_pendingPreloads.containsKey(path)) {
          _pendingPreloads.remove(path);
          count++;
        }
      }
      _cancelledCount += count;

      if (count > 0) {
        AppLogger.i(
          'Cancelled specific preloads: $count images',
          'ImagePreloader',
        );
      }

      return count;
    }
  }

  /// Clear cached images
  ///
  /// This clears Flutter's image cache, freeing memory.
  /// Use this when memory is low or when switching contexts.
  ///
  /// 清除缓存的图片
  ///
  /// 这会清除 Flutter 的图片缓存，释放内存。
  /// 在内存不足或切换上下文时使用。
  void clearCache() {
    try {
      // Clear the image cache
      // 清除图片缓存
      imageCache.clear();

      // Also clear live images (images currently in use)
      // 也清除正在使用的图片
      imageCache.clearLiveImages();

      AppLogger.i(
        'Image cache cleared (success: $_successCount, failures: $_failureCount, '
            'cancelled: $_cancelledCount)',
        'ImagePreloader',
      );

      // Reset statistics
      // 重置统计信息
      _successCount = 0;
      _failureCount = 0;
      _cancelledCount = 0;
    } catch (e) {
      AppLogger.e(
        'Failed to clear image cache',
        e,
        null,
        'ImagePreloader',
      );
    }
  }

  /// Get current cache status
  ///
  /// 获取当前缓存状态
  Map<String, dynamic> get cacheStatus => {
        'pendingCount': _pendingPreloads.length,
        'successCount': _successCount,
        'failureCount': _failureCount,
        'cancelledCount': _cancelledCount,
        'currentCacheSize': imageCache.currentSizeBytes,
        'maxCacheSize': imageCache.maximumSizeBytes,
      };

  /// Check if an image is currently being preloaded
  ///
  /// 检查图片是否正在预加载中
  bool isPending(String imagePath) {
    return _pendingPreloads.containsKey(imagePath);
  }

  /// Get the number of pending preload operations
  ///
  /// 获取待处理的预加载操作数量
  int get pendingCount => _pendingPreloads.length;

  /// Singleton instance
  /// 单例实例
  static final ImagePreloaderService instance = ImagePreloaderService._();
}
