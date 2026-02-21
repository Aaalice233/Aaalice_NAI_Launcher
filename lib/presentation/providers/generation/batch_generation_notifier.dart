import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_models.dart';
import 'image_generation_service.dart';

part 'batch_generation_notifier.g.dart';

// ==================== 批量生成状态枚举 ====================

/// 批量生成状态
enum BatchGenerationStatus {
  idle,
  generating,
  completed,
  error,
  cancelled,
}

// ==================== 批量生成项 ====================

/// 单个生成项的状态
class BatchGenerationItem {
  final String id;
  final int index;
  final Uint8List? image;
  final bool isCompleted;
  final String? error;
  final double progress;
  final DateTime? startTime;
  final DateTime? endTime;

  const BatchGenerationItem({
    required this.id,
    required this.index,
    this.image,
    this.isCompleted = false,
    this.error,
    this.progress = 0.0,
    this.startTime,
    this.endTime,
  });

  BatchGenerationItem copyWith({
    Uint8List? image,
    bool? isCompleted,
    String? error,
    double? progress,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return BatchGenerationItem(
      id: id,
      index: index,
      image: image ?? this.image,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error,
      progress: progress ?? this.progress,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  /// 计算生成耗时（毫秒）
  int? get durationMs {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!).inMilliseconds;
  }

  /// 是否正在生成
  bool get isGenerating =>
      startTime != null && !isCompleted && error == null;

  /// 是否失败
  bool get isFailed => error != null;
}

// ==================== 批量生成状态 ====================

/// 批量生成状态
class BatchGenerationState {
  final BatchGenerationStatus status;
  final List<BatchGenerationItem> items;
  final String? errorMessage;
  final double overallProgress;
  final int completedCount;
  final int failedCount;

  /// 当前批次的分辨率
  final int? batchWidth;
  final int? batchHeight;

  /// 流式预览图像（当前正在生成的预览）
  final Uint8List? streamPreview;

  /// 当前正在生成的索引
  final int currentIndex;

  const BatchGenerationState({
    this.status = BatchGenerationStatus.idle,
    this.items = const [],
    this.errorMessage,
    this.overallProgress = 0.0,
    this.completedCount = 0,
    this.failedCount = 0,
    this.batchWidth,
    this.batchHeight,
    this.streamPreview,
    this.currentIndex = 0,
  });

  BatchGenerationState copyWith({
    BatchGenerationStatus? status,
    List<BatchGenerationItem>? items,
    String? errorMessage,
    double? overallProgress,
    int? completedCount,
    int? failedCount,
    int? batchWidth,
    int? batchHeight,
    Uint8List? streamPreview,
    bool clearStreamPreview = false,
    int? currentIndex,
  }) {
    return BatchGenerationState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: errorMessage,
      overallProgress: overallProgress ?? this.overallProgress,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      batchWidth: batchWidth ?? this.batchWidth,
      batchHeight: batchHeight ?? this.batchHeight,
      streamPreview:
          clearStreamPreview ? null : (streamPreview ?? this.streamPreview),
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  /// 是否正在生成
  bool get isGenerating => status == BatchGenerationStatus.generating;

  /// 是否空闲
  bool get isIdle => status == BatchGenerationStatus.idle;

  /// 总数量
  int get totalCount => items.length;

  /// 是否全部完成
  bool get isAllCompleted =>
      items.isNotEmpty && completedCount + failedCount == items.length;

  /// 获取成功的图像列表
  List<Uint8List> get successfulImages =>
      items.where((i) => i.isCompleted && i.image != null)
          .map((i) => i.image!)
          .toList();

  /// 获取生成的图像对象列表
  List<GeneratedImage> get generatedImages => items
      .where((i) => i.isCompleted && i.image != null)
      .map((i) => GeneratedImage.create(
            i.image!,
            width: batchWidth ?? 832,
            height: batchHeight ?? 1216,
          ),)
      .toList();
}

// ==================== 批量生成 Notifier ====================

/// 批量生成 Notifier
///
/// 用于管理批量/多图像生成的状态，支持：
/// - 并行生成控制
/// - 进度跟踪
/// - 失败重试
/// - 取消支持
@Riverpod(keepAlive: true)
class BatchGenerationNotifier extends _$BatchGenerationNotifier {
  ImageGenerationService? _service;
  bool _isCancelled = false;

  @override
  BatchGenerationState build() {
    ref.onDispose(() {
      _cleanup();
    });
    return const BatchGenerationState();
  }

  /// 清理资源
  void _cleanup() {
    _service = null;
  }

  /// 初始化生成服务
  void _initializeService() {
    if (_service == null) {
      final apiService = ref.read(naiImageGenerationApiServiceProvider);
      _service = ImageGenerationService(apiService: apiService);
    }
  }

  /// 开始批量生成
  ///
  /// [params] 基础生成参数
  /// [count] 生成数量
  /// [concurrency] 并发数（同时生成的数量，默认为1）
  Future<void> generateBatch(
    ImageParams params, {
    required int count,
    int concurrency = 1,
  }) async {
    if (count <= 0) {
      state = state.copyWith(
        status: BatchGenerationStatus.error,
        errorMessage: '生成数量必须大于0',
      );
      return;
    }

    _isCancelled = false;
    _initializeService();

    // 初始化状态
    final items = List<BatchGenerationItem>.generate(
      count,
      (index) => BatchGenerationItem(
        id: 'batch_${DateTime.now().millisecondsSinceEpoch}_$index',
        index: index,
      ),
    );

    state = BatchGenerationState(
      status: BatchGenerationStatus.generating,
      items: items,
      batchWidth: params.width,
      batchHeight: params.height,
      currentIndex: 0,
      overallProgress: 0.0,
    );

    AppLogger.d(
      'Starting batch generation: count=$count, concurrency=$concurrency',
      'BatchGeneration',
    );

    // 使用信号量控制并发
    final semaphore = _Semaphore(concurrency);
    final futures = <Future<void>>[];

    for (int i = 0; i < count; i++) {
      if (_isCancelled) break;

      futures.add(
        semaphore.acquire(() => _generateSingle(params, i, count)),
      );
    }

    try {
      await Future.wait(futures);

      if (_isCancelled) {
        state = state.copyWith(
          status: BatchGenerationStatus.cancelled,
          clearStreamPreview: true,
        );
      } else {
        final completed = state.items.where((i) => i.isCompleted).length;
        final failed = state.items.where((i) => i.isFailed).length;

        state = state.copyWith(
          status: failed == count
              ? BatchGenerationStatus.error
              : BatchGenerationStatus.completed,
          overallProgress: 1.0,
          completedCount: completed,
          failedCount: failed,
          clearStreamPreview: true,
          errorMessage: failed == count ? '所有生成任务失败' : null,
        );

        AppLogger.d(
          'Batch generation completed: completed=$completed, failed=$failed',
          'BatchGeneration',
        );
      }
    } catch (e) {
      if (!_isCancelled) {
        state = state.copyWith(
          status: BatchGenerationStatus.error,
          errorMessage: e.toString(),
          clearStreamPreview: true,
        );
      }
    }
  }

  /// 生成单个图像
  Future<void> _generateSingle(
    ImageParams params,
    int index,
    int total,
  ) async {
    if (_isCancelled) return;

    final startTime = DateTime.now();

    // 更新当前索引和开始时间
    _updateItem(
      index,
      state.items[index].copyWith(
        startTime: startTime,
        progress: 0.0,
      ),
    );

    state = state.copyWith(currentIndex: index + 1);

    try {
      // 为每个图像使用不同的随机种子
      final singleParams = params.copyWith(
        nSamples: 1,
        seed: params.seed == -1 ? -1 : params.seed + index,
      );

      final result = await _service!.generateSingle(
        singleParams,
        onProgress: (current, total, progress, {previewImage}) {
          if (_isCancelled) return;

          // 更新单个项目的进度
          _updateItem(
            index,
            state.items[index].copyWith(progress: progress),
          );

          // 更新总体进度
          final overallProgress = (index + progress) / total;
          state = state.copyWith(
            overallProgress: overallProgress,
            streamPreview: previewImage,
          );
        },
      );

      if (_isCancelled) return;

      if (result.isSuccess && result.images.isNotEmpty) {
        _updateItem(
          index,
          state.items[index].copyWith(
            image: result.images.first.bytes,
            isCompleted: true,
            endTime: DateTime.now(),
            progress: 1.0,
          ),
        );

        // 更新完成计数
        final completed = state.items.where((i) => i.isCompleted).length;
        state = state.copyWith(completedCount: completed);

        AppLogger.d(
          'Generated image ${index + 1}/$total completed',
          'BatchGeneration',
        );
      } else if (result.isCancelled) {
        AppLogger.d('Image $index generation cancelled', 'BatchGeneration');
      } else {
        throw Exception(result.error ?? '生成失败');
      }
    } catch (e) {
      if (_isCancelled) return;

      AppLogger.e('Failed to generate image $index: $e', 'BatchGeneration');

      _updateItem(
        index,
        state.items[index].copyWith(
          error: e.toString(),
          endTime: DateTime.now(),
        ),
      );

      // 更新失败计数
      final failed = state.items.where((i) => i.isFailed).length;
      state = state.copyWith(failedCount: failed);
    }
  }

  /// 更新单个项目
  void _updateItem(int index, BatchGenerationItem updatedItem) {
    final newItems = List<BatchGenerationItem>.from(state.items);
    newItems[index] = updatedItem;
    state = state.copyWith(items: newItems);
  }

  /// 取消批量生成
  void cancel() {
    _isCancelled = true;
    _service?.cancel();

    state = state.copyWith(
      status: BatchGenerationStatus.cancelled,
      clearStreamPreview: true,
    );

    AppLogger.d('Batch generation cancelled', 'BatchGeneration');
  }

  /// 重置状态
  void reset() {
    _isCancelled = false;
    _service?.resetCancellation();
    state = const BatchGenerationState();
  }

  /// 清除错误
  void clearError() {
    if (state.status == BatchGenerationStatus.error) {
      state = state.copyWith(
        status: BatchGenerationStatus.idle,
        errorMessage: null,
      );
    }
  }

  /// 重试失败的生成项
  Future<void> retryFailed(ImageParams params) async {
    final failedIndices = state.items
        .asMap()
        .entries
        .where((e) => e.value.isFailed)
        .map((e) => e.key)
        .toList();

    if (failedIndices.isEmpty) return;

    AppLogger.d(
      'Retrying ${failedIndices.length} failed items',
      'BatchGeneration',
    );

    // 重置失败项的状态
    for (final index in failedIndices) {
      _updateItem(
        index,
        BatchGenerationItem(
          id: state.items[index].id,
          index: index,
        ),
      );
    }

    state = state.copyWith(
      status: BatchGenerationStatus.generating,
      errorMessage: null,
      failedCount: 0,
    );

    // 重试失败的项
    final semaphore = _Semaphore(1);
    final futures = <Future<void>>[];

    for (final index in failedIndices) {
      if (_isCancelled) break;
      futures.add(
        semaphore.acquire(() => _generateSingle(params, index, state.items.length)),
      );
    }

    await Future.wait(futures);

    if (!_isCancelled) {
      final completed = state.items.where((i) => i.isCompleted).length;
      final failed = state.items.where((i) => i.isFailed).length;

      state = state.copyWith(
        status: failed == 0 ? BatchGenerationStatus.completed : BatchGenerationStatus.error,
        overallProgress: 1.0,
        completedCount: completed,
        failedCount: failed,
        errorMessage: failed > 0 ? '$failed 个任务重试后仍失败' : null,
      );
    }
  }

  /// 获取成功的图像列表
  List<GeneratedImage> getSuccessfulImages() {
    return state.generatedImages;
  }

  /// 获取统计信息
  BatchStatistics getStatistics() {
    return BatchStatistics(
      total: state.totalCount,
      completed: state.completedCount,
      failed: state.failedCount,
      overallProgress: state.overallProgress,
      averageDurationMs: _calculateAverageDuration(),
    );
  }

  /// 计算平均生成耗时
  int? _calculateAverageDuration() {
    final completedItems =
        state.items.where((i) => i.isCompleted && i.durationMs != null);
    if (completedItems.isEmpty) return null;

    final totalDuration = completedItems.fold<int>(
      0,
      (sum, item) => sum + item.durationMs!,
    );
    return totalDuration ~/ completedItems.length;
  }
}

// ==================== 信号量（并发控制） ====================

/// 简单的信号量实现，用于控制并发数量
class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _queue = <Completer<void>>[];

  _Semaphore(this.maxCount);

  Future<T> acquire<T>(Future<T> Function() task) async {
    if (_currentCount >= maxCount) {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }

    _currentCount++;
    try {
      return await task();
    } finally {
      _currentCount--;
      if (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        next.complete();
      }
    }
  }
}

// ==================== 批量生成统计 ====================

/// 批量生成统计信息
class BatchStatistics {
  final int total;
  final int completed;
  final int failed;
  final double overallProgress;
  final int? averageDurationMs;

  const BatchStatistics({
    required this.total,
    required this.completed,
    required this.failed,
    required this.overallProgress,
    this.averageDurationMs,
  });

  /// 成功率（0.0 - 1.0）
  double get successRate => total > 0 ? completed / total : 0.0;

  /// 失败率（0.0 - 1.0）
  double get failureRate => total > 0 ? failed / total : 0.0;

  /// 是否全部成功
  bool get isAllSuccessful => completed == total && failed == 0;

  /// 是否全部完成（包括失败）
  bool get isAllDone => completed + failed == total;
}
