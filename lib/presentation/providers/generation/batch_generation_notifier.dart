import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_models.dart';
import 'generation_settings_notifiers.dart';
import 'image_generation_service.dart';
import '../dlss_provider.dart';

part 'batch_generation_notifier.g.dart';

// ==================== 批量生成状态枚举 ====================

/// 批量生成状态
enum BatchGenerationStatus { idle, generating, completed, error, cancelled }

// ==================== 批量生成项 ====================

/// 单个生成项的状态
class BatchGenerationItem {
  final String id;
  final int index;
  final Uint8List? image;
  final bool isCompleted;
  final bool isCancelled;
  final String? error;
  final double progress;
  final DateTime? startTime;
  final DateTime? endTime;

  const BatchGenerationItem({
    required this.id,
    required this.index,
    this.image,
    this.isCompleted = false,
    this.isCancelled = false,
    this.error,
    this.progress = 0.0,
    this.startTime,
    this.endTime,
  });

  BatchGenerationItem copyWith({
    Uint8List? image,
    bool? isCompleted,
    bool? isCancelled,
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
      isCancelled: isCancelled ?? this.isCancelled,
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
      startTime != null && !isCompleted && !isCancelled && error == null;

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
      streamPreview: clearStreamPreview
          ? null
          : (streamPreview ?? this.streamPreview),
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
  List<Uint8List> get successfulImages => items
      .where((i) => i.isCompleted && i.image != null)
      .map((i) => i.image!)
      .toList();

  /// 获取生成的图像对象列表
  List<GeneratedImage> get generatedImages => items
      .where((i) => i.isCompleted && i.image != null)
      .map(
        (i) => GeneratedImage.create(
          i.image!,
          width: batchWidth ?? 832,
          height: batchHeight ?? 1216,
        ),
      )
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
  final Set<ImageGenerationService> _activeServices = {};
  int _epoch = 0;
  int? _cancelledEpoch;

  @override
  BatchGenerationState build() {
    ref.onDispose(_invalidateActiveTasks);
    return const BatchGenerationState();
  }

  bool _isCurrent(int epoch) => epoch == _epoch;

  int _beginEpoch() {
    _invalidateActiveTasks();
    return _epoch;
  }

  void _invalidateActiveTasks() {
    _epoch++;
    for (final service in _activeServices.toList()) {
      service.cancel();
    }
    _activeServices.clear();
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

    final epoch = _beginEpoch();
    final createService = _serviceFactory();

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
      futures.add(
        semaphore.acquire(
          () => _generateSingle(params, i, count, epoch, createService),
        ),
      );
    }

    try {
      // 使用 eagerError: false 确保等待所有任务完成，即使某些任务失败
      await Future.wait(futures, eagerError: false);
      if (!_isCurrent(epoch)) return;

      final completed = state.items.where((i) => i.isCompleted).length;
      final failed = state.items.where((i) => i.isFailed).length;
      final cancelled = state.items.where((i) => i.isCancelled).length;

      state = state.copyWith(
        status: _cancelledEpoch == epoch || cancelled > 0
            ? BatchGenerationStatus.cancelled
            : failed == count
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
    } catch (e) {
      if (_isCurrent(epoch)) {
        state = state.copyWith(
          status: BatchGenerationStatus.error,
          errorMessage: e.toString(),
          clearStreamPreview: true,
        );
      }
    }
  }

  ImageGenerationService Function() _serviceFactory() {
    final dlss = ref.read(dlssProvider);
    final processor = dlss.automaticSnapshot();
    final api = ref.read(naiImageGenerationApiServiceProvider);
    final streamPreview = ref.read(generationStreamPreviewSettingsProvider);
    var reported = false;
    return () => ImageGenerationService(
      apiService: api,
      postprocess: processor,
      onPostprocessError: (error) {
        if (!reported) {
          reported = true;
          dlss.reportEnhancementError(error);
        }
      },
      streamPreviewEnabled: streamPreview,
    );
  }

  /// 生成单个图像
  Future<void> _generateSingle(
    ImageParams params,
    int index,
    int total,
    int epoch,
    ImageGenerationService Function() createService,
  ) async {
    if (!_isCurrent(epoch) || _cancelledEpoch == epoch) return;

    final startTime = DateTime.now();

    // 更新当前索引和开始时间
    _updateItem(
      index,
      (current) => current.copyWith(startTime: startTime, progress: 0.0),
    );

    state = state.copyWith(currentIndex: index + 1);

    try {
      // 为每个图像使用不同的随机种子
      final singleParams = params.copyWith(
        nSamples: 1,
        seed: params.seed == -1 ? -1 : params.seed + index,
      );

      final service = createService();
      _activeServices.add(service);
      late final ImageGenerationResult result;
      try {
        result = await service.generateSingle(
          singleParams,
          onProgress: (current, total, progress, {previewImage}) {
            if (!_isCurrent(epoch)) return;

            // 更新单个项目的进度
            _updateItem(
              index,
              (current) => current.copyWith(progress: progress),
              epoch,
            );

            // 更新总体进度
            final overallProgress = (index + progress) / total;
            state = state.copyWith(
              overallProgress: overallProgress,
              streamPreview: previewImage,
            );
          },
        );
      } finally {
        _activeServices.remove(service);
      }
      if (!_isCurrent(epoch)) return;

      if (result.images.isNotEmpty) {
        _updateItem(
          index,
          (current) => current.copyWith(
            image: result.images.first.bytes,
            isCompleted: true,
            isCancelled: false,
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
        _updateItem(
          index,
          (current) =>
              current.copyWith(isCancelled: true, endTime: DateTime.now()),
          epoch,
        );
        AppLogger.d('Image $index generation cancelled', 'BatchGeneration');
      } else {
        throw Exception(result.error ?? '生成失败');
      }
    } catch (e) {
      if (!_isCurrent(epoch)) return;

      AppLogger.e('Failed to generate image $index: $e', 'BatchGeneration');

      _updateItem(
        index,
        (current) =>
            current.copyWith(error: e.toString(), endTime: DateTime.now()),
      );

      // 更新失败计数
      final failed = state.items.where((i) => i.isFailed).length;
      state = state.copyWith(failedCount: failed);
    }
  }

  /// 更新单个项目（使用原子更新模式避免竞态条件）
  ///
  /// 注意：此方法使用 Riverpod 的原子更新模式，通过读取最新的 state 来确保
  /// 并发任务不会覆盖彼此的状态更新。每次更新都会基于当前最新的 state.items
  /// 进行复制和修改，而不是依赖于调用方传入的旧状态。
  void _updateItem(
    int index,
    BatchGenerationItem Function(BatchGenerationItem current) updater, [
    int? epoch,
  ]) {
    if (epoch != null && !_isCurrent(epoch)) return;
    final currentItems = state.items;
    if (index < 0 || index >= currentItems.length) return;

    final newItems = List<BatchGenerationItem>.from(currentItems);
    newItems[index] = updater(currentItems[index]);
    state = state.copyWith(items: newItems);
  }

  /// 取消批量生成
  void cancel() {
    // Keep this epoch while completed network images finish cancellation of NR.
    // Starting another batch still invalidates the old epoch normally.
    _cancelledEpoch = _epoch;
    for (final service in _activeServices) {
      service.cancel();
    }
    state = state.copyWith(
      status: BatchGenerationStatus.cancelled,
      items: [
        for (final item in state.items)
          item.isCompleted ? item : item.copyWith(isCancelled: true),
      ],
      clearStreamPreview: true,
    );

    AppLogger.d('Batch generation cancelled', 'BatchGeneration');
  }

  /// 重置状态
  void reset() {
    // reset 只清空本地状态，不应把仍由服务端处理的请求解释为用户取消。
    _epoch++;
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

    final epoch = _beginEpoch();
    final createService = _serviceFactory();
    AppLogger.d(
      'Retrying ${failedIndices.length} failed items',
      'BatchGeneration',
    );

    // 重置失败项的状态
    for (final index in failedIndices) {
      _updateItem(
        index,
        (current) => BatchGenerationItem(id: current.id, index: index),
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
      futures.add(
        semaphore.acquire(
          () => _generateSingle(
            params,
            index,
            state.items.length,
            epoch,
            createService,
          ),
        ),
      );
    }

    await Future.wait(futures, eagerError: false);

    if (_isCurrent(epoch)) {
      final completed = state.items.where((i) => i.isCompleted).length;
      final failed = state.items.where((i) => i.isFailed).length;

      state = state.copyWith(
        status: _cancelledEpoch == epoch
            ? BatchGenerationStatus.cancelled
            : failed == 0
            ? BatchGenerationStatus.completed
            : BatchGenerationStatus.error,
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
    final completedItems = state.items.where(
      (i) => i.isCompleted && i.durationMs != null,
    );
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
