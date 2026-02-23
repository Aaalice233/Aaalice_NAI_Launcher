import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../../data/services/image_metadata_service.dart';

part 'metadata_preload_notifier.g.dart';

// ==================== 预加载状态 ====================

/// 预加载状态
enum MetadataPreloadStatus {
  idle,
  loading,
  completed,
  error,
}

/// 预加载统计
class MetadataPreloadStats {
  final int queueLength;
  final int processingCount;
  final int completedCount;
  final int errorCount;
  final int cacheHits;
  final int cacheMisses;

  const MetadataPreloadStats({
    this.queueLength = 0,
    this.processingCount = 0,
    this.completedCount = 0,
    this.errorCount = 0,
    this.cacheHits = 0,
    this.cacheMisses = 0,
  });

  MetadataPreloadStats copyWith({
    int? queueLength,
    int? processingCount,
    int? completedCount,
    int? errorCount,
    int? cacheHits,
    int? cacheMisses,
  }) {
    return MetadataPreloadStats(
      queueLength: queueLength ?? this.queueLength,
      processingCount: processingCount ?? this.processingCount,
      completedCount: completedCount ?? this.completedCount,
      errorCount: errorCount ?? this.errorCount,
      cacheHits: cacheHits ?? this.cacheHits,
      cacheMisses: cacheMisses ?? this.cacheMisses,
    );
  }

  /// 命中率
  double get hitRate {
    final total = cacheHits + cacheMisses;
    return total > 0 ? cacheHits / total : 0.0;
  }

  /// 成功率
  double get successRate {
    final total = completedCount + errorCount;
    return total > 0 ? completedCount / total : 0.0;
  }
}

/// 预加载状态
class MetadataPreloadState {
  final MetadataPreloadStatus status;
  final MetadataPreloadStats stats;
  final String? error;
  final bool isPaused;

  const MetadataPreloadState({
    this.status = MetadataPreloadStatus.idle,
    this.stats = const MetadataPreloadStats(),
    this.error,
    this.isPaused = false,
  });

  MetadataPreloadState copyWith({
    MetadataPreloadStatus? status,
    MetadataPreloadStats? stats,
    String? error,
    bool? isPaused,
  }) {
    return MetadataPreloadState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      error: error,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

/// 预加载任务信息
class MetadataPreloadTask {
  final String taskId;
  final String? filePath;
  final Uint8List? bytes;

  const MetadataPreloadTask({
    required this.taskId,
    this.filePath,
    this.bytes,
  });
}

// ==================== MetadataPreloadNotifier ====================

/// 元数据预加载 Notifier
///
/// 用于在后台预加载图像元数据，提升用户体验。
/// - 生成完成后批量预解析，不阻塞主流程
/// - 支持队列管理和进度跟踪
/// - 缓存命中率高，减少重复解析
@Riverpod(keepAlive: true)
class MetadataPreloadNotifier extends _$MetadataPreloadNotifier {
  ImageMetadataService? _metadataService;
  Timer? _statsUpdateTimer;

  @override
  MetadataPreloadState build() {
    ref.onDispose(() {
      _statsUpdateTimer?.cancel();
    });

    // 初始化元数据服务
    _initializeService();

    // 定期更新统计信息
    _startStatsUpdateTimer();

    return const MetadataPreloadState();
  }

  /// 初始化元数据服务
  Future<void> _initializeService() async {
    try {
      _metadataService = ImageMetadataService();
      await _metadataService!.initialize();
      AppLogger.i('MetadataPreloadNotifier: ImageMetadataService initialized', 'MetadataPreload');
    } catch (e, stack) {
      AppLogger.e('Failed to initialize ImageMetadataService', e, stack, 'MetadataPreload');
      state = state.copyWith(
        status: MetadataPreloadStatus.error,
        error: 'Failed to initialize metadata service: $e',
      );
    }
  }

  /// 启动统计信息更新定时器
  void _startStatsUpdateTimer() {
    _statsUpdateTimer?.cancel();
    _statsUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateStats(),
    );
  }

  /// 更新统计信息
  void _updateStats() {
    if (_metadataService == null) return;

    final stats = _metadataService!.getStats();
    final queueStatus = _metadataService!.getPreloadQueueStatus();

    state = state.copyWith(
      stats: MetadataPreloadStats(
        queueLength: queueStatus['queueLength'] ?? 0,
        processingCount: queueStatus['processingCount'] ?? 0,
        completedCount: queueStatus['successCount'] ?? 0,
        errorCount: queueStatus['errorCount'] ?? 0,
        cacheHits: stats['cacheHits'] ?? 0,
        cacheMisses: stats['cacheMisses'] ?? 0,
      ),
    );
  }

  /// 立即获取元数据（高优先级）
  ///
  /// 用于用户主动打开图像详情页时，不受后台队列影响
  Future<NaiImageMetadata?> getMetadataImmediate(String path) async {
    if (_metadataService == null) {
      AppLogger.w('Metadata service not initialized', 'MetadataPreload');
      return null;
    }

    try {
      return await _metadataService!.getMetadataImmediate(path);
    } catch (e, stack) {
      AppLogger.e('Failed to get metadata immediate: $path', e, stack, 'MetadataPreload');
      return null;
    }
  }

  /// 从文件路径获取元数据（标准优先级）
  Future<NaiImageMetadata?> getMetadata(
    String path, {
    bool forceFullParse = false,
  }) async {
    if (_metadataService == null) {
      AppLogger.w('Metadata service not initialized', 'MetadataPreload');
      return null;
    }

    try {
      return await _metadataService!.getMetadata(path, forceFullParse: forceFullParse);
    } catch (e, stack) {
      AppLogger.e('Failed to get metadata: $path', e, stack, 'MetadataPreload');
      return null;
    }
  }

  /// 从字节数组获取元数据
  Future<NaiImageMetadata?> getMetadataFromBytes(
    Uint8List bytes, {
    String? cacheKey,
  }) async {
    if (_metadataService == null) {
      AppLogger.w('Metadata service not initialized', 'MetadataPreload');
      return null;
    }

    try {
      return await _metadataService!.getMetadataFromBytes(bytes, cacheKey: cacheKey);
    } catch (e, stack) {
      AppLogger.e('Failed to get metadata from bytes', e, stack, 'MetadataPreload');
      return null;
    }
  }

  /// 将图像加入预加载队列（后台解析）
  ///
  /// 用于生成完成后批量预解析，不阻塞主流程
  void enqueuePreload({
    required String taskId,
    String? filePath,
    Uint8List? bytes,
  }) {
    if (_metadataService == null) {
      AppLogger.w('Metadata service not initialized', 'MetadataPreload');
      return;
    }

    if (state.isPaused) {
      AppLogger.d('Preload is paused, skipping enqueue: $taskId', 'MetadataPreload');
      return;
    }

    _metadataService!.enqueuePreload(
      taskId: taskId,
      filePath: filePath,
      bytes: bytes,
    );

    // 更新状态为加载中
    if (state.status != MetadataPreloadStatus.loading) {
      state = state.copyWith(status: MetadataPreloadStatus.loading);
    }

    _updateStats();
  }

  /// 批量预加载
  void enqueuePreloadBatch(List<GeneratedImageInfo> images) {
    if (_metadataService == null) {
      AppLogger.w('Metadata service not initialized', 'MetadataPreload');
      return;
    }

    if (images.isEmpty) return;

    AppLogger.i('Enqueueing ${images.length} images for metadata preload', 'MetadataPreload');

    for (final image in images) {
      enqueuePreload(
        taskId: image.id,
        filePath: image.filePath,
        bytes: image.bytes,
      );
    }
  }

  /// 预加载指定路径的元数据（后台）
  void preload(String path) {
    enqueuePreload(taskId: path, filePath: path);
  }

  /// 批量预加载（兼容旧 API）
  void preloadBatch(List<GeneratedImageInfo> images) {
    enqueuePreloadBatch(images);
  }

  /// 暂停预加载
  void pause() {
    state = state.copyWith(isPaused: true);
    AppLogger.i('Metadata preload paused', 'MetadataPreload');
  }

  /// 恢复预加载
  void resume() {
    state = state.copyWith(isPaused: false);
    AppLogger.i('Metadata preload resumed', 'MetadataPreload');
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 获取缓存中的元数据（同步，可能为 null）
  NaiImageMetadata? getCached(String path) {
    if (_metadataService == null) return null;
    return _metadataService!.getCached(path);
  }

  /// 手动缓存元数据
  void cacheMetadata(String path, NaiImageMetadata metadata) {
    if (_metadataService == null) return;
    _metadataService!.cacheMetadata(path, metadata);
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    if (_metadataService == null) return;
    await _metadataService!.clearCache();
    _updateStats();
  }

  /// 获取详细统计信息
  Map<String, dynamic> getDetailedStats() {
    if (_metadataService == null) {
      return {'error': 'Metadata service not initialized'};
    }
    return _metadataService!.getStats();
  }

  /// 获取预加载队列状态
  Map<String, dynamic> getQueueStatus() {
    if (_metadataService == null) {
      return {'error': 'Metadata service not initialized'};
    }
    return _metadataService!.getPreloadQueueStatus();
  }

  /// 检查元数据是否在缓存中
  bool isCached(String path) {
    return getCached(path) != null;
  }

  /// 生成完成后调用，自动预加载生成图像的元数据
  void onGenerationCompleted(List<GeneratedImageInfo> images) {
    if (images.isEmpty) return;

    AppLogger.i(
      'Generation completed, scheduling metadata preload for ${images.length} images',
      'MetadataPreload',
    );

    // 延迟执行预加载，避免阻塞生成完成后的 UI 更新
    Future.delayed(const Duration(milliseconds: 100), () {
      enqueuePreloadBatch(images);
    });
  }
}

/// 生成的图像信息
///
/// 用于传递给预加载器的数据结构
class GeneratedImageInfo {
  final String id;
  final String? filePath;
  final Uint8List? bytes;

  const GeneratedImageInfo({
    required this.id,
    this.filePath,
    this.bytes,
  });
}
