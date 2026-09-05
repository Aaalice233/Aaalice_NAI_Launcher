import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';

import '../../core/utils/app_logger.dart';
import '../models/gallery/nai_image_metadata.dart';
import 'metadata/cache_manager.dart';
import 'metadata/hash_calculator.dart';
import 'metadata/preloader.dart';
import 'metadata/unified_metadata_parser.dart';

/// 解析任务取消 Token
class ParseCancelToken {
  bool _isCancelled = false;
  final _completer = Completer<void>();

  bool get isCancelled => _isCancelled;
  Future<void> get onCancelled => _completer.future;

  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      _completer.complete();
    }
  }
}

/// 解析任务信息
class _ParseTaskInfo {
  final String hash;
  final DateTime startTime;
  final ParseCancelToken? cancelToken;
  final Completer<NaiImageMetadata?> completer;

  _ParseTaskInfo({
    required this.hash,
    required this.startTime,
    this.cancelToken,
    required this.completer,
  });

  bool get isCancelled => cancelToken?.isCancelled ?? false;
}

/// 解析统计信息
class ParseStatistics {
  int totalParseCount = 0;
  int successfulParseCount = 0;
  int failedParseCount = 0;
  int cancelledParseCount = 0;
  int timeoutParseCount = 0;
  int cacheHitCount = 0;
  final Map<String, int> errorTypeCounts = {};
  Duration totalParseTime = Duration.zero;

  double get averageParseTimeMs =>
      totalParseCount > 0 ? totalParseTime.inMilliseconds / totalParseCount : 0;

  double get successRate =>
      totalParseCount > 0 ? successfulParseCount / totalParseCount : 0;

  Map<String, dynamic> toMap() => {
    'totalParseCount': totalParseCount,
    'successfulParseCount': successfulParseCount,
    'failedParseCount': failedParseCount,
    'cancelledParseCount': cancelledParseCount,
    'timeoutParseCount': timeoutParseCount,
    'cacheHitCount': cacheHitCount,
    'averageParseTimeMs': averageParseTimeMs.toStringAsFixed(2),
    'successRate': '${(successRate * 100).toStringAsFixed(1)}%',
    'errorTypeCounts': errorTypeCounts,
  };

  void recordSuccess(Duration duration) {
    totalParseCount++;
    successfulParseCount++;
    totalParseTime += duration;
  }

  void recordFailure(String errorType, Duration duration) {
    totalParseCount++;
    failedParseCount++;
    totalParseTime += duration;
    errorTypeCounts[errorType] = (errorTypeCounts[errorType] ?? 0) + 1;
  }

  void recordCancelled() {
    totalParseCount++;
    cancelledParseCount++;
  }

  void recordTimeout() {
    totalParseCount++;
    timeoutParseCount++;
  }

  void recordCacheHit() {
    cacheHitCount++;
  }

  void reset() {
    totalParseCount = 0;
    successfulParseCount = 0;
    failedParseCount = 0;
    cancelledParseCount = 0;
    timeoutParseCount = 0;
    cacheHitCount = 0;
    errorTypeCounts.clear();
    totalParseTime = Duration.zero;
  }
}

/// 图像元数据服务
///
/// 统一的元数据解析服务入口，使用文件内容哈希作为缓存键，支持重命名免疫。
///
/// 架构分层：
/// - ImageMetadataService: 主服务，协调各组件
/// - MetadataCacheManager: L1/L2 缓存管理
/// - FileHashCalculator: 文件哈希计算
/// - MetadataPreloader: 后台预加载队列
/// - UnifiedMetadataParser: 统一元数据解析器
///
/// 新特性：
/// - 单文件解析超时控制（默认 5 秒）
/// - 解析任务取消支持
/// - 详细的解析统计
/// - 增强的错误处理
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

  // 任务管理
  final _pendingTasks = <String, _ParseTaskInfo>{};
  final _activeTimeouts = <String, Timer>{};

  // 统计
  final _statistics = ParseStatistics();

  // 配置
  static const Duration _defaultParseTimeout = Duration(seconds: 5);
  static const Duration _highPriorityTimeout = Duration(seconds: 3);

  /// 初始化服务
  Future<void> initialize() async {
    await _cacheManager.initialize();
  }

  /// 前台立即获取元数据（高优先级）
  ///
  /// [path] 文件路径
  /// [cancelToken] 可选的取消令牌
  Future<NaiImageMetadata?> getMetadataImmediate(
    String path, {
    ParseCancelToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 检查取消
    if (cancelToken?.isCancelled ?? false) {
      _statistics.recordCancelled();
      return null;
    }

    final hash = await _hashCalculator.calculate(path);

    // 检查 L1 内存缓存
    final memoryCached = _cacheManager.getFromMemory(hash);
    if (memoryCached != null) {
      stopwatch.stop();
      _statistics.recordCacheHit();
      return memoryCached;
    }

    // 检查 L2 持久化缓存
    final persistentCached = _cacheManager.getFromPersistent(hash);
    if (persistentCached != null) {
      stopwatch.stop();
      _statistics.recordCacheHit();
      return persistentCached;
    }

    // 检查是否有正在进行的解析
    final existingTask = _pendingTasks[hash];
    if (existingTask != null) {
      return existingTask.completer.future;
    }

    // 高优先级解析
    await _highPrioritySemaphore.acquire();

    // 创建任务
    final taskCompleter = Completer<NaiImageMetadata?>();
    final taskInfo = _ParseTaskInfo(
      hash: hash,
      startTime: DateTime.now(),
      cancelToken: cancelToken,
      completer: taskCompleter,
    );
    _pendingTasks[hash] = taskInfo;

    // 设置超时
    final timeoutTimer = Timer(_highPriorityTimeout, () {
      if (!taskCompleter.isCompleted) {
        AppLogger.w('[MetadataFlow] Parse timeout for: $path', 'ImageMetadataService');
        _statistics.recordTimeout();
        taskCompleter.complete(null);
      }
    });
    _activeTimeouts[hash] = timeoutTimer;

    try {
      // 执行解析
      final result = await _parseAndCache(
        path,
        hash: hash,
        cancelToken: cancelToken,
        isHighPriority: true,
      );

      stopwatch.stop();

      if (!taskCompleter.isCompleted) {
        taskCompleter.complete(result);
      }

      return result;
    } on _ParseCancelledException {
      _statistics.recordCancelled();
      if (!taskCompleter.isCompleted) {
        taskCompleter.complete(null);
      }
      return null;
    } catch (e, stack) {
      AppLogger.e('[MetadataFlow] Parse error', e, stack, 'ImageMetadataService');
      if (!taskCompleter.isCompleted) {
        taskCompleter.complete(null);
      }
      return null;
    } finally {
      _cleanupTask(hash);
      _highPrioritySemaphore.release();
    }
  }

  /// 从文件路径获取元数据（标准入口）
  ///
  /// [path] 文件路径
  /// [cancelToken] 可选的取消令牌
  /// [timeout] 解析超时时间（默认 5 秒）
  Future<NaiImageMetadata?> getMetadata(
    String path, {
    ParseCancelToken? cancelToken,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 检查取消
    if (cancelToken?.isCancelled ?? false) {
      _statistics.recordCancelled();
      return null;
    }

    final hash = await _hashCalculator.calculate(path);

    // 检查 L1 内存缓存
    final memoryCached = _cacheManager.getFromMemory(hash);
    if (memoryCached != null) {
      _statistics.recordCacheHit();
      return memoryCached;
    }

    // 检查 L2 持久化缓存
    final persistentCached = _cacheManager.getFromPersistent(hash);
    if (persistentCached != null) {
      _statistics.recordCacheHit();
      return persistentCached;
    }

    // 检查是否有正在进行的解析
    final existingTask = _pendingTasks[hash];
    if (existingTask != null) {
      return existingTask.completer.future;
    }

    await _fileSemaphore.acquire();

    // 创建任务
    final taskCompleter = Completer<NaiImageMetadata?>();
    final taskInfo = _ParseTaskInfo(
      hash: hash,
      startTime: DateTime.now(),
      cancelToken: cancelToken,
      completer: taskCompleter,
    );
    _pendingTasks[hash] = taskInfo;

    // 设置超时
    final actualTimeout = timeout ?? _defaultParseTimeout;
    final timeoutTimer = Timer(actualTimeout, () {
      if (!taskCompleter.isCompleted) {
        AppLogger.w('[MetadataFlow] Parse timeout for: $path', 'ImageMetadataService');
        _statistics.recordTimeout();
        taskCompleter.complete(null);
      }
    });
    _activeTimeouts[hash] = timeoutTimer;

    try {
      final result = await _parseAndCache(
        path,
        hash: hash,
        cancelToken: cancelToken,
      );

      stopwatch.stop();
      if (stopwatch.elapsedMilliseconds > 50) {
        AppLogger.w(
          '[PERF] Slow getMetadata: ${stopwatch.elapsedMilliseconds}ms for $path',
          'ImageMetadataService',
        );
      }

      if (!taskCompleter.isCompleted) {
        taskCompleter.complete(result);
      }

      return result;
    } on _ParseCancelledException {
      _statistics.recordCancelled();
      if (!taskCompleter.isCompleted) {
        taskCompleter.complete(null);
      }
      return null;
    } catch (e, stack) {
      AppLogger.e('[MetadataFlow] Parse error', e, stack, 'ImageMetadataService');
      if (!taskCompleter.isCompleted) {
        taskCompleter.complete(null);
      }
      return null;
    } finally {
      _cleanupTask(hash);
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
    final existingTask = _pendingTasks[hash];
    if (existingTask != null) {
      return existingTask.completer.future;
    }

    // 创建任务
    final taskCompleter = Completer<NaiImageMetadata?>();
    final taskInfo = _ParseTaskInfo(
      hash: hash,
      startTime: DateTime.now(),
      completer: taskCompleter,
    );
    _pendingTasks[hash] = taskInfo;

    try {
      final result = await _parseBytesAndCache(bytes, hash: hash);

      if (!taskCompleter.isCompleted) {
        taskCompleter.complete(result);
      }

      return result;
    } catch (e, stack) {
      AppLogger.e('Parse bytes failed', e, stack, 'ImageMetadataService');
      if (!taskCompleter.isCompleted) {
        taskCompleter.complete(null);
      }
      return null;
    } finally {
      _cleanupTask(hash);
    }
  }

  /// 从字节数组获取包含失败原因的完整解析结果。
  ///
  /// 拖入菜单需要区分“没有元数据”和“载荷损坏”，因此不能只返回
  /// nullable metadata 后再重复解析整张图片。
  Future<MetadataParseResult> getMetadataParseResultFromBytes(
    Uint8List bytes,
  ) async {
    final hash = _hashCalculator.calculateFromBytes(bytes);
    final cached =
        _cacheManager.getFromMemory(hash) ??
        _cacheManager.getFromPersistent(hash);
    if (cached != null) {
      return MetadataParseResult.success(
        cached,
        'cache',
        cached.rawJson ?? '',
        const ['cache'],
        bytesRead: bytes.length,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = UnifiedMetadataParser.parseFromImage(bytes);
      final metadata = result.success ? result.metadata : null;
      if (metadata != null && metadata.hasData) {
        try {
          await _cacheManager.save(hash, metadata);
        } catch (e) {
          AppLogger.w(
            'Failed to cache parsed image metadata: $e',
            'ImageMetadataService',
          );
        }
        _statistics.recordSuccess(stopwatch.elapsed);
      } else {
        _statistics.recordFailure(
          result.errorMessage ?? 'unknown',
          stopwatch.elapsed,
        );
      }
      return result;
    } catch (e, stack) {
      _statistics.recordFailure(
        'exception: ${e.runtimeType}',
        stopwatch.elapsed,
      );
      AppLogger.e('Parse bytes failed', e, stack, 'ImageMetadataService');
      return MetadataParseResult.failed(
        const [],
        e.toString(),
        parseTime: stopwatch.elapsed,
        bytesRead: bytes.length,
      );
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

  /// 从缓存获取元数据（同步检查）
  NaiImageMetadata? getCached(String path) {

    final hash = _hashCalculator.getHashForPath(path);
    if (hash == null) return null;

    // 检查 L1 内存缓存
    final memoryCached = _cacheManager.getFromMemory(hash);
    if (memoryCached != null) {
      return memoryCached;
    }

    // 检查 L2 持久化缓存
    final persistentCached = _cacheManager.getFromPersistent(hash);
    if (persistentCached != null) {
      return persistentCached;
    }
    return null;
  }

  /// 取消指定路径的解析任务
  void cancelParse(String path) {
    final hash = _hashCalculator.getHashForPath(path);
    if (hash != null) {
      _cancelTask(hash);
    }
  }

  /// 取消所有进行中的解析任务
  void cancelAllParses() {
    final hashes = List<String>.from(_pendingTasks.keys);
    for (final hash in hashes) {
      _cancelTask(hash);
    }
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    await _cacheManager.clear();
    _hashCalculator.clearCache();
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

  /// 获取解析统计
  ParseStatistics get parseStatistics => _statistics;

  /// 重置统计
  void resetStatistics() {
    _cacheManager.resetStatistics();
    _hashCalculator.resetStatistics();
    _preloader.resetStatistics();
    _statistics.reset();
  }

  /// 获取完整统计
  Map<String, dynamic> getStats() => {
    ..._cacheManager.getStatistics(),
    ..._hashCalculator.getStatistics(),
    ..._preloader.getStatistics(),
    ..._statistics.toMap(),
    'pendingTasks': _pendingTasks.length,
    'activeTimeouts': _activeTimeouts.length,
  };

  /// 获取预加载队列状态
  Map<String, dynamic> getPreloadQueueStatus() => _preloader.getStatistics();

  // ==================== 私有方法 ====================

  void _cleanupTask(String hash) {
    _pendingTasks.remove(hash);
    _activeTimeouts[hash]?.cancel();
    _activeTimeouts.remove(hash);
  }

  void _cancelTask(String hash) {
    final task = _pendingTasks[hash];
    if (task != null && !task.completer.isCompleted) {
      task.completer.complete(null);
      _cleanupTask(hash);
    }
  }

  void _checkCancelled(ParseCancelToken? token) {
    if (token?.isCancelled ?? false) {
      throw const _ParseCancelledException();
    }
  }

  Future<NaiImageMetadata?> _parseAndCache(
    String path, {
    required String hash,
    ParseCancelToken? cancelToken,
    bool isHighPriority = false,
  }) async {
    final totalStopwatch = Stopwatch()..start();

    try {
      _checkCancelled(cancelToken);

      final file = File(path);
      // 检查文件是否存在
      if (!await file.exists()) {
        AppLogger.w('[MetadataFlow] File NOT FOUND: $path', 'ImageMetadataService');
        _statistics.recordFailure('file_not_found', totalStopwatch.elapsed);
        return null;
      }

      _checkCancelled(cancelToken);

      NaiImageMetadata? metadata;
      String? parseError;

      // 容器格式由解析器根据文件签名判断，不能依赖拖拽来源是否提供扩展名。
      final parseStopwatch = Stopwatch()..start();

      try {
        _checkCancelled(cancelToken);

        final result = UnifiedMetadataParser.parseFromFile(
          path,
          useGradualRead: true,
          useCache: true,
        );

        parseStopwatch.stop();

        if (result.success && result.metadata != null) {
          metadata = result.metadata;
        } else {
          parseError = result.errorMessage;
        }
      } catch (e, _) {
        parseStopwatch.stop();
        AppLogger.w('[MetadataFlow] Unified parse error: $e', 'ImageMetadataService');
        metadata = null;
      }

      _checkCancelled(cancelToken);

      // 缓存结果
      if (metadata != null && metadata.hasData) {
        await _cacheManager.save(hash, metadata);
        _statistics.recordSuccess(totalStopwatch.elapsed);
      } else {
        if (metadata == null) {
          _statistics.recordFailure(
            parseError ?? 'no_metadata',
            totalStopwatch.elapsed,
          );
        } else {
          _statistics.recordFailure('empty_metadata', totalStopwatch.elapsed);
        }
      }

      totalStopwatch.stop();
      if (totalStopwatch.elapsedMilliseconds > 100) {
        AppLogger.w(
          '[PERF] Slow _parseAndCache: ${totalStopwatch.elapsedMilliseconds}ms for $path',
          'ImageMetadataService',
        );
      }

      return metadata;
    } on _ParseCancelledException {
      rethrow;
    } catch (e, stack) {
      totalStopwatch.stop();
      _statistics.recordFailure('exception: ${e.runtimeType}', totalStopwatch.elapsed);
      AppLogger.e('[MetadataFlow] Parse FAILED: $path', e, stack, 'ImageMetadataService');
      return null;
    }
  }

  Future<NaiImageMetadata?> _parseBytesAndCache(
    Uint8List bytes, {
    required String hash,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      if (bytes.length < 8) {
        _statistics.recordFailure('bytes_too_small', stopwatch.elapsed);
        return null;
      }

      final result = UnifiedMetadataParser.parseFromImage(bytes);
      final metadata = result.success ? result.metadata : null;

      if (metadata != null && metadata.hasData) {
        await _cacheManager.save(hash, metadata);
        _statistics.recordSuccess(stopwatch.elapsed);
      } else {
        _statistics.recordFailure(result.errorMessage ?? 'unknown', stopwatch.elapsed);
      }

      return metadata;
    } catch (e, stack) {
      _statistics.recordFailure('exception: ${e.runtimeType}', stopwatch.elapsed);
      AppLogger.e('Parse bytes failed', e, stack, 'ImageMetadataService');
      return null;
    }
  }
}

/// 解析取消异常
class _ParseCancelledException implements Exception {
  const _ParseCancelledException();
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
