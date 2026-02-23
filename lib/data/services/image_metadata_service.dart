import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../../core/utils/app_logger.dart';
import '../../core/utils/nai_metadata_parser.dart';
import '../../core/utils/png_metadata_extractor.dart';
import '../models/gallery/nai_image_metadata.dart';
import 'metadata/cache_manager.dart';
import 'metadata/hash_calculator.dart';
import 'metadata/preloader.dart';

/// 图像元数据服务
///
/// 统一的元数据解析服务入口，使用文件内容哈希作为缓存键，支持重命名免疫。
///
/// 架构分层：
/// - ImageMetadataService: 主服务，协调各组件
/// - MetadataCacheManager: L1/L2 缓存管理
/// - FileHashCalculator: 文件哈希计算
/// - MetadataPreloader: 后台预加载队列
class ImageMetadataService {
  static final ImageMetadataService _instance = ImageMetadataService._internal();
  factory ImageMetadataService() => _instance;
  ImageMetadataService._internal();

  // 子组件
  final _cacheManager = MetadataCacheManager();
  final _hashCalculator = FileHashCalculator();
  final _preloader = MetadataPreloader();

  // 并发控制
  final _fileSemaphore = _Semaphore(3);
  final _highPrioritySemaphore = _Semaphore(2);
  final _pendingFutures = <String, Future<NaiImageMetadata?>>{};

  // 统计
  int _fastParseCount = 0;
  int _fallbackParseCount = 0;
  int _parseErrors = 0;

  /// 初始化服务
  Future<void> initialize() async {
    await _cacheManager.initialize();
  }

  /// 前台立即获取元数据（高优先级）
  Future<NaiImageMetadata?> getMetadataImmediate(String path) async {
    final hash = await _hashCalculator.calculate(path);

    // 检查 L1 内存缓存
    final memoryCached = _cacheManager.getFromMemory(hash);
    if (memoryCached != null) return memoryCached;

    // 检查 L2 持久化缓存
    final persistentCached = _cacheManager.getFromPersistent(hash);
    if (persistentCached != null) {
      return persistentCached;
    }

    // 检查是否有正在进行的解析
    if (_pendingFutures.containsKey(hash)) {
      return _pendingFutures[hash]!;
    }

    // 高优先级解析
    await _highPrioritySemaphore.acquire();
    final future = _parseAndCache(path, hash: hash);
    _pendingFutures[hash] = future;

    try {
      return await future;
    } finally {
      _pendingFutures.remove(hash);
      _highPrioritySemaphore.release();
    }
  }

  /// 从文件路径获取元数据（标准入口）
  Future<NaiImageMetadata?> getMetadata(String path) async {
    final stopwatch = Stopwatch()..start();
    final hash = await _hashCalculator.calculate(path);

    // 检查 L1 内存缓存
    final memoryCached = _cacheManager.getFromMemory(hash);
    if (memoryCached != null) return memoryCached;

    // 检查 L2 持久化缓存
    final persistentCached = _cacheManager.getFromPersistent(hash);
    if (persistentCached != null) {
      return persistentCached;
    }

    // 检查是否有正在进行的解析
    if (_pendingFutures.containsKey(hash)) {
      return _pendingFutures[hash]!;
    }

    await _fileSemaphore.acquire();
    final future = _parseAndCache(path, hash: hash);
    _pendingFutures[hash] = future;

    try {
      final result = await future;
      stopwatch.stop();
      if (stopwatch.elapsedMilliseconds > 50) {
        AppLogger.w('[PERF] Slow getMetadata: ${stopwatch.elapsedMilliseconds}ms for $path', 'ImageMetadataService');
      }
      return result;
    } finally {
      _pendingFutures.remove(hash);
      _fileSemaphore.release();
    }
  }

  /// 从字节数组获取元数据
  Future<NaiImageMetadata?> getMetadataFromBytes(Uint8List bytes) async {
    final hash = _hashCalculator.calculateFromBytes(bytes);

    // 检查 L1 内存缓存
    final memoryCached = _cacheManager.getFromMemory(hash);
    if (memoryCached != null) return memoryCached;

    // 检查 L2 持久化缓存
    final persistentCached = _cacheManager.getFromPersistent(hash);
    if (persistentCached != null) {
      return persistentCached;
    }

    // 检查是否有正在进行的解析
    if (_pendingFutures.containsKey(hash)) {
      return _pendingFutures[hash]!;
    }

    final future = _parseBytesAndCache(bytes, hash: hash);
    _pendingFutures[hash] = future;

    try {
      return await future;
    } finally {
      _pendingFutures.remove(hash);
    }
  }

  /// 手动缓存元数据
  Future<void> cacheMetadata(String path, NaiImageMetadata metadata) async {
    if (!metadata.hasData) return;
    final hash = await _hashCalculator.calculate(path);
    await _cacheManager.save(hash, metadata);
  }

  /// 将图像加入预加载队列
  void enqueuePreload({
    required String taskId,
    String? filePath,
    Uint8List? bytes,
  }) {
    _preloader.enqueue(taskId: taskId, filePath: filePath, bytes: bytes);
  }

  /// 批量添加预加载任务
  void enqueuePreloadBatch(List<GeneratedImageInfo> images) {
    for (final image in images) {
      enqueuePreload(taskId: image.id, filePath: image.filePath, bytes: image.bytes);
    }
  }

  /// 从缓存获取元数据（同步检查）
  NaiImageMetadata? getCached(String path) {
    final hash = _hashCalculator.getHashForPath(path);
    if (hash == null) return null;

    return _cacheManager.getFromMemory(hash) ?? _cacheManager.getFromPersistent(hash);
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    await _cacheManager.clear();
    _hashCalculator.clearCache();
    AppLogger.i('All caches cleared', 'ImageMetadataService');
  }

  /// 清除持久化缓存
  Future<void> clearPersistentCache() async {
    await _cacheManager.clearPersistent();
  }

  /// 通知路径变更（文件重命名检测）
  void notifyPathChanged(String oldPath, String newPath) {
    _hashCalculator.notifyPathChanged(oldPath, newPath);
  }

  /// 预加载（简写）
  void preload(String path) => enqueuePreload(taskId: path, filePath: path);

  /// 批量预加载
  void preloadBatch(List<GeneratedImageInfo> images) => enqueuePreloadBatch(images);

  // ==================== 统计信息 ====================

  /// L1 内存缓存大小
  int get memoryCacheSize => _cacheManager.memorySize;

  /// L1 内存缓存命中率
  double get memoryCacheHitRate => _cacheManager.memoryHitRate;

  /// L2 持久化缓存大小
  Future<int> get persistentCacheSize async => _cacheManager.persistentSize;

  /// L2 持久化缓存命中率
  double get persistentCacheHitRate => _cacheManager.persistentHitRate;

  /// Hive 缓存 Box（用于 L2CacheCleaner 访问）
  Box<String>? get persistentBox => _cacheManager.box;

  /// 获取哈希对应的所有路径
  List<String> getPathsForHash(String hash) => _hashCalculator.getPathsForHash(hash);

  /// 重置统计
  void resetStatistics() {
    _cacheManager.resetStatistics();
    _hashCalculator.resetStatistics();
    _preloader.resetStatistics();
    _fastParseCount = 0;
    _fallbackParseCount = 0;
    _parseErrors = 0;
    AppLogger.i('ImageMetadataService statistics reset', 'ImageMetadataService');
  }

  /// 获取完整统计
  Map<String, dynamic> getStats() => {
    ..._cacheManager.getStatistics(),
    ..._hashCalculator.getStatistics(),
    ..._preloader.getStatistics(),
    'fastParseCount': _fastParseCount,
    'fallbackParseCount': _fallbackParseCount,
    'parseErrors': _parseErrors,
  };

  /// 获取预加载队列状态
  Map<String, dynamic> getPreloadQueueStatus() => _preloader.getStatistics();

  // ==================== 私有方法 ====================

  Future<NaiImageMetadata?> _parseAndCache(
    String path, {
    required String hash,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    try {
      final file = File(path);
      if (!await file.exists()) {
        AppLogger.w('[Metadata] File not found: $path', 'ImageMetadataService');
        return null;
      }
      if (!path.toLowerCase().endsWith('.png')) {
        AppLogger.w('[Metadata] Not a PNG file: $path', 'ImageMetadataService');
        return null;
      }

      NaiImageMetadata? metadata;

      // 快速解析
      final fastStopwatch = Stopwatch()..start();
      metadata = PngMetadataExtractor.extractFromFile(path, maxBytes: 50 * 1024);
      fastStopwatch.stop();
      if (metadata != null) {
        _fastParseCount++;
      }

      // 回退到完整解析
      if (metadata == null) {
        final fallbackStopwatch = Stopwatch()..start();
        metadata = await NaiMetadataParser.extractFromFile(file);
        fallbackStopwatch.stop();
        if (metadata != null) {
          _fallbackParseCount++;
        }
      }

      // 缓存结果
      if (metadata != null && metadata.hasData) {
        await _cacheManager.save(hash, metadata);
        AppLogger.d('[Metadata] Parsed and cached: $path', 'ImageMetadataService');
      }

      totalStopwatch.stop();
      if (totalStopwatch.elapsedMilliseconds > 100) {
        AppLogger.w('[PERF] Slow _parseAndCache: ${totalStopwatch.elapsedMilliseconds}ms for $path', 'ImageMetadataService');
      }

      return metadata;
    } catch (e, stack) {
      _parseErrors++;
      AppLogger.e('[Metadata] Parse failed: $path', e, stack, 'ImageMetadataService');
      return null;
    }
  }

  Future<NaiImageMetadata?> _parseBytesAndCache(
    Uint8List bytes, {
    required String hash,
  }) async {
    try {
      if (bytes.length < 8) return null;

      NaiImageMetadata? metadata = PngMetadataExtractor.extractFromBytes(bytes);
      metadata ??= await NaiMetadataParser.extractFromBytes(bytes);

      if (metadata != null && metadata.hasData) {
        await _cacheManager.save(hash, metadata);
      }

      return metadata;
    } catch (e, stack) {
      _parseErrors++;
      AppLogger.e('Parse bytes failed', e, stack, 'ImageMetadataService');
      return null;
    }
  }
}

/// 生成图像信息
class GeneratedImageInfo {
  final String id;
  final String? filePath;
  final Uint8List? bytes;

  GeneratedImageInfo({required this.id, this.filePath, this.bytes});
}

/// 信号量
class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _waitQueue = <Completer<void>>[];

  _Semaphore(this.maxCount);

  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      _waitQueue.removeAt(0).complete();
    } else {
      _currentCount--;
    }
  }
}
