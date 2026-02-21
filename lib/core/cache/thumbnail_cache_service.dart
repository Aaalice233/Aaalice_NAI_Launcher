import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_logger.dart';

part 'thumbnail_cache_service.g.dart';

/// 缩略图信息
class ThumbnailInfo {
  final String path;
  final int width;
  final int height;
  final DateTime createdAt;
  DateTime lastAccessedAt;
  int accessCount;

  ThumbnailInfo({
    required this.path,
    required this.width,
    required this.height,
    required this.createdAt,
    DateTime? lastAccessedAt,
    this.accessCount = 1,
  }) : lastAccessedAt = lastAccessedAt ?? createdAt;

  /// 记录访问
  void recordAccess() {
    accessCount++;
    lastAccessedAt = DateTime.now();
  }

  /// 转换为 JSON（用于持久化）
  Map<String, dynamic> toJson() => {
        'path': path,
        'width': width,
        'height': height,
        'createdAt': createdAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
        'accessCount': accessCount,
      };

  /// 从 JSON 创建
  factory ThumbnailInfo.fromJson(Map<String, dynamic> json) {
    return ThumbnailInfo(
      path: json['path'] as String,
      width: json['width'] as int,
      height: json['height'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.parse(json['lastAccessedAt'] as String)
          : null,
      accessCount: json['accessCount'] as int? ?? 1,
    );
  }
}

/// 缩略图缓存服务
///
/// 负责缩略图的生成、缓存和检索
///
/// 特性：
/// - 磁盘缓存缩略图，避免重复解码原始大图
/// - 使用 LRU 淘汰策略管理缓存空间
/// - 异步生成缩略图，不阻塞 UI
/// - 与原图保持相同目录结构，存储在.thumbs子目录下
class ThumbnailCacheService {
  /// 缩略图目标尺寸
  static const int targetWidth = 180;
  static const int targetHeight = 220;

  /// 缩略图质量 (JPEG)
  static const int jpegQuality = 85;

  /// 缩略图子目录名称
  static const String thumbsDirName = '.thumbs';

  /// 缩略图文件扩展名
  static const String thumbnailExt = '.thumb.jpg';

  /// 最大并发生成数
  static const int maxConcurrentGenerations = 2;

  /// 正在生成的缩略图路径集合
  final Set<String> _generatingThumbnails = {};

  /// 缩略图生成队列
  final List<_ThumbnailTask> _taskQueue = [];

  /// 当前正在进行的生成任务数
  int _activeGenerationCount = 0;

  /// 统计信息
  int _hitCount = 0;
  int _missCount = 0;
  int _generatedCount = 0;
  int _failedCount = 0;
  int _evictedCount = 0;

  /// 缓存限制配置
  static const int defaultMaxCacheSizeMB = 500;
  static const int defaultMaxFileCount = 10000;

  /// LRU 追踪：缩略图路径 -> 最后访问时间
  final Map<String, DateTime> _lastAccessTimes = {};

  /// 缓存大小限制（MB）
  int _maxCacheSizeMB = defaultMaxCacheSizeMB;

  /// 最大文件数限制
  int _maxFileCount = defaultMaxFileCount;

  /// 初始化服务
  Future<void> init() async {
    AppLogger.d('ThumbnailCacheService initialized', 'ThumbnailCache');
  }

  /// 设置缓存限制
  ///
  /// [maxSizeMB] 最大缓存大小（MB）
  /// [maxFiles] 最大文件数量
  void setCacheLimits({int? maxSizeMB, int? maxFiles}) {
    if (maxSizeMB != null && maxSizeMB > 0) {
      _maxCacheSizeMB = maxSizeMB;
    }
    if (maxFiles != null && maxFiles > 0) {
      _maxFileCount = maxFiles;
    }
    AppLogger.d(
      'Cache limits updated: maxSize=${_maxCacheSizeMB}MB, maxFiles=$_maxFileCount',
      'ThumbnailCache',
    );
  }

  /// 获取缩略图路径
  ///
  /// 如果缩略图已存在，直接返回路径
  /// 如果不存在，返回 null，需要调用 generateThumbnail 生成
  ///
  /// [originalPath] 原始图片路径
  String? getThumbnailPath(String originalPath) {
    final thumbnailPath = _getThumbnailPath(originalPath);
    final file = File(thumbnailPath);

    if (file.existsSync()) {
      _hitCount++;
      // 记录访问时间用于 LRU
      _lastAccessTimes[thumbnailPath] = DateTime.now();
      AppLogger.d('Thumbnail cache HIT: $thumbnailPath', 'ThumbnailCache');
      return thumbnailPath;
    }

    _missCount++;
    AppLogger.d('Thumbnail cache MISS: $originalPath', 'ThumbnailCache');
    return null;
  }

  /// 异步获取或生成缩略图
  ///
  /// 如果缩略图已存在，直接返回路径
  /// 如果不存在，异步生成缩略图并返回路径
  ///
  /// [originalPath] 原始图片路径
  Future<String?> getOrGenerateThumbnail(String originalPath) async {
    // 首先检查缓存
    final existingPath = getThumbnailPath(originalPath);
    if (existingPath != null) {
      return existingPath;
    }

    // 检查文件是否存在
    final originalFile = File(originalPath);
    if (!await originalFile.exists()) {
      AppLogger.w(
        'Original file not found: $originalPath',
        'ThumbnailCache',
      );
      return null;
    }

    // 生成缩略图
    return generateThumbnail(originalPath);
  }

  /// 生成缩略图
  ///
  /// [originalPath] 原始图片路径
  /// 返回生成的缩略图路径，失败返回 null
  Future<String?> generateThumbnail(String originalPath) async {
    final thumbnailPath = _getThumbnailPath(originalPath);

    // 检查是否已在生成中
    if (_generatingThumbnails.contains(originalPath)) {
      AppLogger.d(
        'Thumbnail generation already in progress: $originalPath',
        'ThumbnailCache',
      );
      // 等待生成完成
      return _waitForGeneration(originalPath);
    }

    // 检查是否已存在（可能在等待期间其他任务已生成）
    final file = File(thumbnailPath);
    if (await file.exists()) {
      _hitCount++;
      return thumbnailPath;
    }

    // 如果并发数已达上限，加入队列
    if (_activeGenerationCount >= maxConcurrentGenerations) {
      AppLogger.d(
        'Thumbnail generation queued: $originalPath',
        'ThumbnailCache',
      );
      return _queueGeneration(originalPath);
    }

    // 直接生成
    return _doGenerateThumbnail(originalPath);
  }

  /// 实际执行缩略图生成
  Future<String?> _doGenerateThumbnail(String originalPath) async {
    final thumbnailPath = _getThumbnailPath(originalPath);
    _generatingThumbnails.add(originalPath);
    _activeGenerationCount++;

    final stopwatch = Stopwatch()..start();

    try {
      // 确保缩略图目录存在
      final thumbDir = Directory(_getThumbnailDir(originalPath));
      if (!await thumbDir.exists()) {
        await thumbDir.create(recursive: true);
      }

      // 读取并解码原始图片
      final file = File(originalPath);
      final bytes = await file.readAsBytes();

      // 使用 image 包解码
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image: $originalPath');
      }

      // 计算缩略图尺寸（保持宽高比）
      final aspectRatio = originalImage.width / originalImage.height;
      int thumbWidth = targetWidth;
      int thumbHeight = targetHeight;

      if (aspectRatio > targetWidth / targetHeight) {
        // 图片较宽，以宽度为准
        thumbHeight = (targetWidth / aspectRatio).round();
      } else {
        // 图片较高，以高度为准
        thumbWidth = (targetHeight * aspectRatio).round();
      }

      // 生成缩略图
      final thumbnail = img.copyResize(
        originalImage,
        width: thumbWidth,
        height: thumbHeight,
        interpolation: img.Interpolation.linear,
      );

      // 编码为 JPEG
      final thumbBytes = img.encodeJpg(thumbnail, quality: jpegQuality);

      // 写入文件
      await File(thumbnailPath).writeAsBytes(thumbBytes);

      stopwatch.stop();
      _generatedCount++;

      AppLogger.i(
        'Thumbnail generated: ${originalPath.split('/').last} '
        '(${originalImage.width}x${originalImage.height} -> '
        '${thumbnail.width}x${thumbnail.height}) '
        'in ${stopwatch.elapsedMilliseconds}ms',
        'ThumbnailCache',
      );

      return thumbnailPath;
    } catch (e, stack) {
      _failedCount++;
      AppLogger.e(
        'Failed to generate thumbnail for $originalPath: $e',
        e,
        stack,
        'ThumbnailCache',
      );
      return null;
    } finally {
      _generatingThumbnails.remove(originalPath);
      _activeGenerationCount--;
      _processQueue();
    }
  }

  /// 将生成任务加入队列
  Future<String?> _queueGeneration(String originalPath) {
    final completer = Completer<String?>();
    _taskQueue.add(
      _ThumbnailTask(
        originalPath: originalPath,
        completer: completer,
      ),
    );
    return completer.future;
  }

  /// 等待正在进行的生成任务完成
  Future<String?> _waitForGeneration(String originalPath) async {
    // 轮询检查生成是否完成
    for (var i = 0; i < 100; i++) {
      // 最多等待 10 秒
      await Future.delayed(const Duration(milliseconds: 100));

      if (!_generatingThumbnails.contains(originalPath)) {
        // 生成已完成，检查文件是否存在
        final thumbnailPath = _getThumbnailPath(originalPath);
        if (await File(thumbnailPath).exists()) {
          return thumbnailPath;
        }
        return null;
      }
    }

    AppLogger.w(
      'Timeout waiting for thumbnail generation: $originalPath',
      'ThumbnailCache',
    );
    return null;
  }

  /// 处理队列中的任务
  void _processQueue() {
    if (_taskQueue.isEmpty) return;
    if (_activeGenerationCount >= maxConcurrentGenerations) return;

    final task = _taskQueue.removeAt(0);
    _doGenerateThumbnail(task.originalPath).then((path) {
      task.completer.complete(path);
    }).catchError((error) {
      task.completer.completeError(error);
    });
  }

  /// 删除缩略图
  ///
  /// [originalPath] 原始图片路径
  Future<bool> deleteThumbnail(String originalPath) async {
    try {
      final thumbnailPath = _getThumbnailPath(originalPath);
      final file = File(thumbnailPath);

      if (await file.exists()) {
        await file.delete();
        AppLogger.d('Thumbnail deleted: $thumbnailPath', 'ThumbnailCache');
        return true;
      }

      return false;
    } catch (e, stack) {
      AppLogger.e(
        'Failed to delete thumbnail for $originalPath: $e',
        e,
        stack,
        'ThumbnailCache',
      );
      return false;
    }
  }

  /// 批量删除缩略图
  ///
  /// [originalPaths] 原始图片路径列表
  Future<int> deleteThumbnails(List<String> originalPaths) async {
    int deletedCount = 0;

    for (final path in originalPaths) {
      if (await deleteThumbnail(path)) {
        deletedCount++;
      }
    }

    AppLogger.i(
      'Batch deleted $deletedCount/${originalPaths.length} thumbnails',
      'ThumbnailCache',
    );

    return deletedCount;
  }

  /// 清理整个缩略图缓存
  ///
  /// [rootPath] 画廊根目录路径，用于定位所有 .thumbs 目录
  /// [options] 清理选项，可选参数：
  ///   - 'resetStats': bool - 是否重置统计信息（默认 true）
  ///   - 'preserveAccessTimes': bool - 是否保留访问时间记录（默认 false）
  /// 返回被删除的目录数量
  Future<int> clearCache(String rootPath, {Map<String, dynamic>? options}) async {
    try {
      final rootDir = Directory(rootPath);
      if (!await rootDir.exists()) {
        AppLogger.w('Root directory not found: $rootPath', 'ThumbnailCache');
        return 0;
      }

      final resetStats = options?['resetStats'] as bool? ?? true;
      final preserveAccessTimes = options?['preserveAccessTimes'] as bool? ?? false;

      int deletedCount = 0;
      int totalSize = 0;
      int fileCount = 0;
      final List<String> deletedPaths = [];

      // 遍历所有子目录，删除 .thumbs 文件夹
      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is Directory) {
          final dirName = entity.path.split(Platform.pathSeparator).last;
          if (dirName == thumbsDirName) {
            // 统计大小和文件数
            await for (final file in entity.list(recursive: true)) {
              if (file is File) {
                totalSize += await file.length();
                fileCount++;
                deletedPaths.add(file.path);
              }
            }

            await entity.delete(recursive: true);
            deletedCount++;
          }
        }
      }

      // 清理访问时间记录
      if (!preserveAccessTimes) {
        _lastAccessTimes.clear();
      } else {
        // 只删除已不存在的文件的访问记录
        for (final path in deletedPaths) {
          _lastAccessTimes.remove(path);
        }
      }

      // 重置统计（可选）
      if (resetStats) {
        _hitCount = 0;
        _missCount = 0;
        _generatedCount = 0;
        _failedCount = 0;
        _evictedCount = 0;
      }

      AppLogger.i(
        'Cache cleared: $deletedCount directories, $fileCount files, '
        '${_formatBytes(totalSize)} freed',
        'ThumbnailCache',
      );

      return deletedCount;
    } catch (e, stack) {
      AppLogger.e('Failed to clear cache: $e', e, stack, 'ThumbnailCache');
      return 0;
    }
  }

  /// 清理指定时间之前的缩略图（按创建时间）
  ///
  /// [rootPath] 画廊根目录路径
  /// [before] 清理此时间之前创建的缩略图
  /// 返回被删除的文件数量
  Future<int> clearCacheBefore(String rootPath, DateTime before) async {
    try {
      final rootDir = Directory(rootPath);
      if (!await rootDir.exists()) {
        return 0;
      }

      int deletedCount = 0;
      int freedSize = 0;

      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is Directory) {
          final dirName = entity.path.split(Platform.pathSeparator).last;
          if (dirName == thumbsDirName) {
            await for (final file in entity.list(recursive: true)) {
              if (file is File) {
                try {
                  final stat = await file.stat();
                  if (stat.modified.isBefore(before)) {
                    freedSize += await file.length();
                    await file.delete();
                    _lastAccessTimes.remove(file.path);
                    deletedCount++;
                  }
                } catch (_) {
                  // 忽略无法删除的文件
                }
              }
            }
          }
        }
      }

      AppLogger.i(
        'Cache cleared before $before: $deletedCount files, ${_formatBytes(freedSize)} freed',
        'ThumbnailCache',
      );

      return deletedCount;
    } catch (e, stack) {
      AppLogger.e('Failed to clear cache before date: $e', e, stack, 'ThumbnailCache');
      return 0;
    }
  }

  /// 格式化字节数为可读字符串
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  /// 获取缓存统计
  ///
  /// 返回包含命中统计、队列状态、限制配置等信息的 Map
  Map<String, dynamic> getStats() {
    final totalRequests = _hitCount + _missCount;
    final hitRate = totalRequests > 0
        ? (_hitCount / totalRequests * 100)
        : 0.0;

    return {
      // 命中统计
      'hitCount': _hitCount,
      'missCount': _missCount,
      'generatedCount': _generatedCount,
      'failedCount': _failedCount,
      'evictedCount': _evictedCount,
      'hitRate': '${hitRate.toStringAsFixed(1)}%',
      'hitRateValue': hitRate,

      // 队列状态
      'queueLength': _taskQueue.length,
      'activeGenerations': _activeGenerationCount,
      'maxConcurrentGenerations': maxConcurrentGenerations,

      // 限制配置
      'maxCacheSizeMB': _maxCacheSizeMB,
      'maxFileCount': _maxFileCount,

      // LRU 追踪数量
      'trackedAccessTimes': _lastAccessTimes.length,
    };
  }

  /// 获取详细的缓存统计（包含磁盘使用情况）
  ///
  /// [rootPath] 画廊根目录路径
  Future<Map<String, dynamic>> getDetailedStats(String rootPath) async {
    final basicStats = getStats();
    final cacheSizeInfo = await getCacheSize(rootPath);

    return {
      ...basicStats,
      'diskCache': cacheSizeInfo,
    };
  }

  /// 重置统计信息
  void resetStats() {
    _hitCount = 0;
    _missCount = 0;
    _generatedCount = 0;
    _failedCount = 0;
    _evictedCount = 0;
    _lastAccessTimes.clear();
    AppLogger.d('Statistics reset', 'ThumbnailCache');
  }

  /// 获取指定目录的缩略图缓存大小
  ///
  /// [rootPath] 画廊根目录路径
  Future<Map<String, dynamic>> getCacheSize(String rootPath) async {
    try {
      final rootDir = Directory(rootPath);
      if (!await rootDir.exists()) {
        return {'fileCount': 0, 'totalSize': 0, 'totalSizeMB': 0.0};
      }

      int fileCount = 0;
      int totalSize = 0;

      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is Directory) {
          final dirName = entity.path.split(Platform.pathSeparator).last;
          if (dirName == thumbsDirName) {
            await for (final file in entity.list(recursive: true)) {
              if (file is File) {
                fileCount++;
                totalSize += await file.length();
              }
            }
          }
        }
      }

      return {
        'fileCount': fileCount,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
      };
    } catch (e, stack) {
      AppLogger.e('Failed to get cache size: $e', e, stack, 'ThumbnailCache');
      return {'fileCount': 0, 'totalSize': 0, 'totalSizeMB': 0.0};
    }
  }

  /// 检查缩略图是否存在
  bool thumbnailExists(String originalPath) {
    final thumbnailPath = _getThumbnailPath(originalPath);
    return File(thumbnailPath).existsSync();
  }

  /// 执行 LRU 淘汰
  ///
  /// [rootPath] 画廊根目录路径
  /// [targetSizeMB] 目标缓存大小（MB），默认使用 _maxCacheSizeMB 的 80%
  /// [targetFileCount] 目标文件数，默认使用 _maxFileCount 的 80%
  /// 返回被淘汰的文件数量
  Future<int> evictLRU(
    String rootPath, {
    int? targetSizeMB,
    int? targetFileCount,
  }) async {
    try {
      final targetSize = (targetSizeMB ?? (_maxCacheSizeMB * 0.8)).toInt();
      final targetFiles = targetFileCount ?? (_maxFileCount * 0.8).toInt();

      // 获取所有缩略图文件信息
      final allThumbnails = await _getAllThumbnails(rootPath);

      if (allThumbnails.isEmpty) {
        return 0;
      }

      // 计算当前缓存状态
      int currentSizeMB = 0;
      for (final info in allThumbnails) {
        try {
          final file = File(info.path);
          if (await file.exists()) {
            currentSizeMB += await file.length();
          }
        } catch (_) {
          // 忽略无法访问的文件
        }
      }
      currentSizeMB = currentSizeMB ~/ (1024 * 1024);

      // 检查是否需要淘汰
      if (currentSizeMB <= targetSize && allThumbnails.length <= targetFiles) {
        AppLogger.d(
          'LRU eviction skipped: size=$currentSizeMBMB/${targetSize}MB, '
          'files=${allThumbnails.length}/$targetFiles',
          'ThumbnailCache',
        );
        return 0;
      }

      // 按最后访问时间排序（最久未访问的在前）
      allThumbnails.sort((a, b) {
        final aTime = _lastAccessTimes[a.path] ?? a.createdAt;
        final bTime = _lastAccessTimes[b.path] ?? b.createdAt;
        return aTime.compareTo(bTime);
      });

      int evictedCount = 0;
      int evictedSizeMB = 0;

      // 淘汰直到满足限制
      for (final info in allThumbnails) {
        if (currentSizeMB - evictedSizeMB <= targetSize &&
            allThumbnails.length - evictedCount <= targetFiles) {
          break;
        }

        try {
          final file = File(info.path);
          if (await file.exists()) {
            final fileSize = await file.length();
            await file.delete();
            evictedSizeMB += fileSize ~/ (1024 * 1024);
            evictedCount++;
            _lastAccessTimes.remove(info.path);
          }
        } catch (e) {
          AppLogger.w('Failed to evict thumbnail: ${info.path}', 'ThumbnailCache');
        }
      }

      _evictedCount += evictedCount;

      AppLogger.i(
        'LRU eviction completed: $evictedCount files, ${evictedSizeMB}MB freed, '
        'remaining: ${allThumbnails.length - evictedCount} files, '
        '${currentSizeMB - evictedSizeMB}MB',
        'ThumbnailCache',
      );

      return evictedCount;
    } catch (e, stack) {
      AppLogger.e('LRU eviction failed: $e', e, stack, 'ThumbnailCache');
      return 0;
    }
  }

  /// 获取所有缩略图信息
  Future<List<ThumbnailInfo>> _getAllThumbnails(String rootPath) async {
    final List<ThumbnailInfo> thumbnails = [];

    try {
      final rootDir = Directory(rootPath);
      if (!await rootDir.exists()) {
        return thumbnails;
      }

      await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
        if (entity is Directory) {
          final dirName = entity.path.split(Platform.pathSeparator).last;
          if (dirName == thumbsDirName) {
            await for (final file in entity.list(recursive: true)) {
              if (file is File && file.path.endsWith(thumbnailExt)) {
                try {
                  final stat = await file.stat();
                  thumbnails.add(
                    ThumbnailInfo(
                      path: file.path,
                      width: 0, // 磁盘缓存不保存具体尺寸
                      height: 0,
                      createdAt: stat.modified,
                      lastAccessedAt: _lastAccessTimes[file.path] ?? stat.accessed,
                      accessCount: 1,
                    ),
                  );
                } catch (_) {
                  // 忽略无法访问的文件
                }
              }
            }
          }
        }
      }
    } catch (e, stack) {
      AppLogger.e('Failed to get all thumbnails: $e', e, stack, 'ThumbnailCache');
    }

    return thumbnails;
  }

  /// 获取缩略图文件路径
  String _getThumbnailPath(String originalPath) {
    final dir = _getThumbnailDir(originalPath);
    final fileName = _getThumbnailFileName(originalPath);
    return '$dir${Platform.pathSeparator}$fileName';
  }

  /// 获取缩略图目录路径
  String _getThumbnailDir(String originalPath) {
    final originalDir = File(originalPath).parent.path;
    return '$originalDir${Platform.pathSeparator}$thumbsDirName';
  }

  /// 获取缩略图文件名
  String _getThumbnailFileName(String originalPath) {
    final originalFileName = originalPath.split(Platform.pathSeparator).last;
    // 移除原始扩展名，添加缩略图扩展名
    final baseName = originalFileName.substring(
      0,
      originalFileName.lastIndexOf('.'),
    );
    return '$baseName$thumbnailExt';
  }
}

/// 缩略图生成任务
class _ThumbnailTask {
  final String originalPath;
  final Completer<String?> completer;

  _ThumbnailTask({
    required this.originalPath,
    required this.completer,
  });
}

/// ThumbnailCacheService Provider
@riverpod
ThumbnailCacheService thumbnailCacheService(Ref ref) {
  return ThumbnailCacheService();
}
