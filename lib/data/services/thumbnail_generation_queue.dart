import 'dart:async';

import '../../core/cache/thumbnail_cache_service.dart';
import '../../core/utils/app_logger.dart';

/// 缩略图生成队列任务
///
/// 表示队列中的一个缩略图生成任务
class ThumbnailQueueTask {
  /// 原始图片路径
  final String originalPath;

  /// 任务创建时间
  final DateTime createdAt;

  /// 任务完成回调
  final void Function(String? thumbnailPath)? onComplete;

  /// 任务优先级（数字越小优先级越高）
  final int priority;

  /// 重试次数
  int retryCount;

  ThumbnailQueueTask({
    required this.originalPath,
    this.onComplete,
    this.priority = 5,
    this.retryCount = 0,
  }) : createdAt = DateTime.now();

  @override
  String toString() =>
      'ThumbnailQueueTask(path: $originalPath, priority: $priority)';
}

/// 缩略图生成批次
///
/// 表示一批待生成的缩略图任务
class ThumbnailGenerationBatch {
  /// 批次ID
  final String id;

  /// 批次中的任务
  final List<ThumbnailQueueTask> tasks;

  /// 批次创建时间
  final DateTime createdAt;

  /// 批次优先级
  final int priority;

  /// 批次描述（用于日志）
  final String description;

  /// 已完成任务数
  int completedCount;

  /// 失败任务数
  int failedCount;

  /// 是否已取消
  bool isCancelled;

  ThumbnailGenerationBatch({
    required this.id,
    required this.tasks,
    required this.description,
    this.priority = 5,
  })  : createdAt = DateTime.now(),
        completedCount = 0,
        failedCount = 0,
        isCancelled = false;

  /// 获取总任务数
  int get totalCount => tasks.length;

  /// 获取进度（0.0 - 1.0）
  double get progress =>
      totalCount > 0 ? (completedCount + failedCount) / totalCount : 0.0;

  /// 检查批次是否已完成
  bool get isCompleted => (completedCount + failedCount) >= totalCount;

  @override
  String toString() =>
      'ThumbnailGenerationBatch(id: $id, tasks: $totalCount, progress: ${(progress * 100).toStringAsFixed(1)}%)';
}

/// 队列处理状态
enum QueueProcessingState {
  /// 空闲状态
  idle,

  /// 正在处理
  processing,

  /// 已暂停
  paused,
}

/// 缩略图生成队列服务
///
/// 用于后台批量生成缩略图，避免阻塞UI
///
/// 特性：
/// - 支持批量任务的优先级队列
/// - 并发控制，避免系统过载
/// - 后台批量生成，不阻塞UI线程
/// - 支持任务取消和暂停
/// - 详细的进度追踪和统计
class ThumbnailGenerationQueue {
  ThumbnailGenerationQueue._()
      : maxConcurrentGenerations = 2,
        maxRetryAttempts = 3 {
    AppLogger.d('ThumbnailGenerationQueue initialized', 'ThumbnailQueue');
  }

  /// 最大并发生成数
  final int maxConcurrentGenerations;

  /// 最大重试次数
  final int maxRetryAttempts;

  /// 缩略图缓存服务
  ThumbnailCacheService? _thumbnailService;

  /// 任务队列（按优先级排序）
  final List<ThumbnailQueueTask> _taskQueue = [];

  /// 活跃批次映射
  final Map<String, ThumbnailGenerationBatch> _activeBatches = {};

  /// 当前正在进行的生成任务数
  int _activeGenerationCount = 0;

  /// 队列处理状态
  QueueProcessingState _state = QueueProcessingState.idle;

  /// 状态流控制器
  final StreamController<QueueProcessingState> _stateController =
      StreamController<QueueProcessingState>.broadcast();

  /// 进度流控制器
  final StreamController<ThumbnailGenerationBatch> _progressController =
      StreamController<ThumbnailGenerationBatch>.broadcast();

  /// 全局统计
  int _totalGenerated = 0;
  int _totalFailed = 0;
  int _totalCancelled = 0;

  /// 初始化队列服务
  ///
  /// [thumbnailService] 缩略图缓存服务实例
  void init(ThumbnailCacheService thumbnailService) {
    _thumbnailService = thumbnailService;
    AppLogger.i(
      'ThumbnailGenerationQueue initialized with service',
      'ThumbnailQueue',
    );
  }

  /// 获取当前状态
  QueueProcessingState get state => _state;

  /// 状态流
  Stream<QueueProcessingState> get stateStream => _stateController.stream;

  /// 进度流
  Stream<ThumbnailGenerationBatch> get progressStream =>
      _progressController.stream;

  /// 获取队列长度
  int get queueLength => _taskQueue.length;

  /// 获取活跃批次数量
  int get activeBatchCount => _activeBatches.length;

  /// 获取活跃生成任务数
  int get activeGenerationCount => _activeGenerationCount;

  /// 添加批量生成任务到队列
  ///
  /// [imagePaths] 原始图片路径列表
  /// [description] 批次描述（用于日志）
  /// [priority] 批次优先级（数字越小优先级越高，默认5）
  /// [onBatchProgress] 批次进度回调
  /// 返回批次ID
  ///
  /// 批量添加图片路径到生成队列，在后台并发生成缩略图
  /// 使用并发控制避免系统过载，不阻塞UI线程
  Future<String> enqueueBatch(
    List<String> imagePaths, {
    String description = 'Batch',
    int priority = 5,
    void Function(ThumbnailGenerationBatch batch)? onBatchProgress,
  }) async {
    if (imagePaths.isEmpty) {
      AppLogger.d('Empty batch ignored', 'ThumbnailQueue');
      return '';
    }

    // 生成批次ID
    final batchId =
        'batch_${DateTime.now().millisecondsSinceEpoch}_${_activeBatches.length}';

    // 创建任务列表
    final tasks = imagePaths.map((path) {
      return ThumbnailQueueTask(
        originalPath: path,
        priority: priority,
      );
    }).toList();

    // 创建批次
    final batch = ThumbnailGenerationBatch(
      id: batchId,
      tasks: tasks,
      description: description,
      priority: priority,
    );

    // 添加到活跃批次
    _activeBatches[batchId] = batch;

    // 将任务加入队列
    for (final task in tasks) {
      _taskQueue.add(task);
    }

    AppLogger.i(
      'Enqueued batch $batchId: ${imagePaths.length} images, priority=$priority',
      'ThumbnailQueue',
    );

    // 启动处理（如果未在运行）
    _startProcessing();

    return batchId;
  }

  /// 添加单个生成任务到队列
  ///
  /// [imagePath] 原始图片路径
  /// [priority] 任务优先级（数字越小优先级越高）
  /// [onComplete] 完成回调
  Future<void> enqueueTask(
    String imagePath, {
    int priority = 5,
    void Function(String? thumbnailPath)? onComplete,
  }) async {
    final task = ThumbnailQueueTask(
      originalPath: imagePath,
      priority: priority,
      onComplete: onComplete,
    );

    _taskQueue.add(task);

    AppLogger.d(
      'Enqueued task: $imagePath, priority=$priority',
      'ThumbnailQueue',
    );

    // 启动处理（如果未在运行）
    _startProcessing();
  }

  /// 启动队列处理
  void _startProcessing() {
    if (_state == QueueProcessingState.processing) return;
    if (_thumbnailService == null) {
      AppLogger.w(
        'Thumbnail service not initialized, cannot start processing',
        'ThumbnailQueue',
      );
      return;
    }

    _setState(QueueProcessingState.processing);
    _processQueue();
  }

  /// 设置队列状态
  void _setState(QueueProcessingState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      AppLogger.d('Queue state changed to: $newState', 'ThumbnailQueue');
    }
  }

  /// 处理队列中的任务
  Future<void> _processQueue() async {
    while (_state == QueueProcessingState.processing &&
        _activeGenerationCount < maxConcurrentGenerations &&
        _taskQueue.isNotEmpty) {
      // 获取下一个任务（按优先级排序）
      _taskQueue.sort((a, b) => a.priority.compareTo(b.priority));
      final task = _taskQueue.removeAt(0);

      // 并发处理
      _activeGenerationCount++;

      // 修复: 添加异常处理，防止未捕获的异常导致队列处理中断
      try {
        await _processTask(task);
      } catch (e, stack) {
        AppLogger.e(
          'Unexpected error in queue processing: $e',
          e,
          stack,
          'ThumbnailQueue',
        );
        // 确保失败任务被正确计数
        _totalFailed++;
      } finally {
        _activeGenerationCount--;
        // 继续处理队列
        _processQueue();
      }
    }

    // 检查是否所有任务已完成
    if (_taskQueue.isEmpty && _activeGenerationCount == 0) {
      _setState(QueueProcessingState.idle);
      AppLogger.i('Queue processing completed', 'ThumbnailQueue');
    }
  }

  /// 处理单个任务
  Future<void> _processTask(ThumbnailQueueTask task) async {
    try {
      // 检查缩略图服务是否可用
      if (_thumbnailService == null) {
        throw Exception('Thumbnail service not initialized');
      }

      // 生成缩略图
      final thumbnailPath =
          await _thumbnailService!.generateThumbnail(task.originalPath);

      if (thumbnailPath != null) {
        _totalGenerated++;
        AppLogger.d(
          'Generated thumbnail: ${task.originalPath.split('/').last}',
          'ThumbnailQueue',
        );
      } else {
        _totalFailed++;
        AppLogger.w(
          'Failed to generate thumbnail: ${task.originalPath}',
          'ThumbnailQueue',
        );
      }

      // 调用完成回调
      task.onComplete?.call(thumbnailPath);

      // 更新批次状态
      _updateBatchStatus(task.originalPath, thumbnailPath != null);
    } catch (e, stack) {
      _totalFailed++;
      AppLogger.e(
        'Error processing thumbnail task: ${task.originalPath}',
        e,
        stack,
        'ThumbnailQueue',
      );

      // 重试逻辑
      if (task.retryCount < maxRetryAttempts) {
        task.retryCount++;
        AppLogger.d(
          'Retrying task (attempt ${task.retryCount}): ${task.originalPath}',
          'ThumbnailQueue',
        );
        _taskQueue.add(task);
      } else {
        task.onComplete?.call(null);
        _updateBatchStatus(task.originalPath, false);
      }
    }
  }

  /// 更新批次状态
  void _updateBatchStatus(String originalPath, bool success) {
    // 查找包含此任务的批次
    for (final batch in _activeBatches.values) {
      final taskExists = batch.tasks.any(
        (t) => t.originalPath == originalPath,
      );

      if (taskExists) {
        if (success) {
          batch.completedCount++;
        } else {
          batch.failedCount++;
        }

        // 发送进度更新
        _progressController.add(batch);

        // 如果批次完成，记录日志
        if (batch.isCompleted) {
          AppLogger.i(
            'Batch ${batch.id} completed: ${batch.completedCount} success, '
                '${batch.failedCount} failed',
            'ThumbnailQueue',
          );
        }

        break;
      }
    }
  }

  /// 暂停队列处理
  void pause() {
    if (_state == QueueProcessingState.processing) {
      _setState(QueueProcessingState.paused);
      AppLogger.i('Queue processing paused', 'ThumbnailQueue');
    }
  }

  /// 恢复队列处理
  void resume() {
    if (_state == QueueProcessingState.paused) {
      _setState(QueueProcessingState.processing);
      _processQueue();
      AppLogger.i('Queue processing resumed', 'ThumbnailQueue');
    }
  }

  /// 取消特定批次的所有任务
  ///
  /// [batchId] 批次ID
  /// 返回取消的任务数量
  int cancelBatch(String batchId) {
    final batch = _activeBatches[batchId];
    if (batch == null) {
      AppLogger.w('Batch not found: $batchId', 'ThumbnailQueue');
      return 0;
    }

    batch.isCancelled = true;

    // 统计被取消的任务（仍在队列中的）
    int cancelledCount = 0;
    final remainingTasks = <ThumbnailQueueTask>[];

    while (_taskQueue.isNotEmpty) {
      final task = _taskQueue.removeFirst();
      if (batch.tasks.any((t) => t.originalPath == task.originalPath)) {
        cancelledCount++;
      } else {
        remainingTasks.add(task);
      }
    }

    // 将未取消的任务加回队列
    for (final task in remainingTasks) {
      _taskQueue.add(task);
    }

    _totalCancelled += cancelledCount;

    AppLogger.i(
      'Cancelled batch $batchId: $cancelledCount tasks',
      'ThumbnailQueue',
    );

    return cancelledCount;
  }

  /// 取消所有任务
  ///
  /// 返回取消的任务数量
  int cancelAll() {
    final cancelledCount = _taskQueue.length;
    _taskQueue.clear();

    // 标记所有批次为已取消
    for (final batch in _activeBatches.values) {
      batch.isCancelled = true;
    }

    _totalCancelled += cancelledCount;

    if (cancelledCount > 0) {
      AppLogger.i(
        'Cancelled all tasks: $cancelledCount',
        'ThumbnailQueue',
      );
    }

    return cancelledCount;
  }

  /// 获取批次信息
  ///
  /// [batchId] 批次ID
  ThumbnailGenerationBatch? getBatch(String batchId) {
    return _activeBatches[batchId];
  }

  /// 获取所有活跃批次
  List<ThumbnailGenerationBatch> getActiveBatches() {
    return _activeBatches.values.toList();
  }

  /// 清理已完成的批次
  ///
  /// [maxAge] 最大保留时间，默认为1小时
  int cleanupCompletedBatches({Duration? maxAge}) {
    final age = maxAge ?? const Duration(hours: 1);
    final now = DateTime.now();
    final toRemove = <String>[];

    _activeBatches.forEach((id, batch) {
      if (batch.isCompleted && now.difference(batch.createdAt) > age) {
        toRemove.add(id);
      }
    });

    for (final id in toRemove) {
      _activeBatches.remove(id);
    }

    if (toRemove.isNotEmpty) {
      AppLogger.d(
        'Cleaned up ${toRemove.length} completed batches',
        'ThumbnailQueue',
      );
    }

    return toRemove.length;
  }

  /// 获取队列统计信息
  Map<String, dynamic> getStats() {
    return {
      // 队列状态
      'state': _state.toString(),
      'queueLength': _taskQueue.length,
      'activeBatches': _activeBatches.length,
      'activeGenerations': _activeGenerationCount,
      'maxConcurrentGenerations': maxConcurrentGenerations,

      // 统计
      'totalGenerated': _totalGenerated,
      'totalFailed': _totalFailed,
      'totalCancelled': _totalCancelled,
      'totalProcessed': _totalGenerated + _totalFailed + _totalCancelled,

      // 批次详情
      'batches': _activeBatches.values.map((b) => {
            'id': b.id,
            'description': b.description,
            'total': b.totalCount,
            'completed': b.completedCount,
            'failed': b.failedCount,
            'progress': b.progress,
            'isCompleted': b.isCompleted,
            'isCancelled': b.isCancelled,
          }).toList(),
    };
  }

  /// 获取详细状态报告
  String getStatusReport() {
    final stats = getStats();
    final buffer = StringBuffer();

    buffer.writeln('=== Thumbnail Generation Queue Status ===');
    buffer.writeln('State: ${stats['state']}');
    buffer.writeln('Queue Length: ${stats['queueLength']}');
    buffer.writeln(
        'Active Generations: ${stats['activeGenerations']}/${stats['maxConcurrentGenerations']}',);
    buffer.writeln('');
    buffer.writeln('Statistics:');
    buffer.writeln('  Generated: ${stats['totalGenerated']}');
    buffer.writeln('  Failed: ${stats['totalFailed']}');
    buffer.writeln('  Cancelled: ${stats['totalCancelled']}');
    buffer.writeln('');

    if (stats['batches'].isNotEmpty) {
      buffer.writeln('Active Batches:');
      for (final batch in stats['batches']) {
        buffer.writeln(
            '  ${batch['id']}: ${batch['description']} - '
                '${((batch['progress'] as double) * 100).toStringAsFixed(1)}% '
                '(${batch['completed']}/${batch['total']})',);
      }
    }

    return buffer.toString();
  }

  /// 重置统计信息
  void resetStats() {
    _totalGenerated = 0;
    _totalFailed = 0;
    _totalCancelled = 0;
    AppLogger.d('Statistics reset', 'ThumbnailQueue');
  }

  /// 释放资源
  void dispose() {
    cancelAll();
    _stateController.close();
    _progressController.close();
    AppLogger.i('ThumbnailGenerationQueue disposed', 'ThumbnailQueue');
  }

  /// 单例实例
  static final ThumbnailGenerationQueue instance =
      ThumbnailGenerationQueue._();
}
