import 'dart:async';
import 'dart:typed_data';

import '../../../core/utils/app_logger.dart';

/// 元数据预加载任务
class PreloadTask {
  final String taskId;
  final String? filePath;
  final Uint8List? bytes;

  PreloadTask({required this.taskId, this.filePath, this.bytes});
}

/// 元数据预加载器
///
/// 管理后台预加载队列，支持：
/// - 优先级队列
/// - 并发控制
/// - 去重（相同任务只执行一次）
/// - 进度跟踪
class MetadataPreloader {
  static final MetadataPreloader _instance = MetadataPreloader._internal();
  factory MetadataPreloader() => _instance;
  MetadataPreloader._internal();

  final _queue = <PreloadTask>[];
  final _processingTaskIds = <String>{};
  final _semaphore = _Semaphore(3);

  bool _isProcessingQueue = false;

  // 统计
  int _successCount = 0;
  int _errorCount = 0;

  /// 添加预加载任务
  ///
  /// [taskId] 任务唯一标识（通常是文件路径或哈希）
  /// [filePath] 文件路径（与 bytes 二选一）
  /// [bytes] 字节数据（与 filePath 二选一）
  bool enqueue({
    required String taskId,
    String? filePath,
    Uint8List? bytes,
    int maxQueueSize = 100,
  }) {
    // 检查是否已在队列或正在处理
    if (_processingTaskIds.contains(taskId)) return false;
    if (_queue.any((t) => t.taskId == taskId)) return false;

    // 队列满了则跳过
    if (_queue.length >= maxQueueSize) {
      AppLogger.w('Preload queue full, skipping: $taskId', 'MetadataPreloader');
      return false;
    }

    _queue.add(PreloadTask(taskId: taskId, filePath: filePath, bytes: bytes));
    _startQueueProcessor();
    return true;
  }

  /// 批量添加预加载任务
  int enqueueBatch(
    List<String> taskIds, {
    required List<String?> filePaths,
    required List<Uint8List?> bytesList,
    int maxQueueSize = 100,
  }) {
    var added = 0;
    for (var i = 0; i < taskIds.length; i++) {
      if (enqueue(
        taskId: taskIds[i],
        filePath: filePaths[i],
        bytes: bytesList[i],
        maxQueueSize: maxQueueSize,
      )) {
        added++;
      }
    }
    return added;
  }

  /// 启动队列处理器
  void _startQueueProcessor() {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    _processQueue();
  }

  /// 处理队列
  Future<void> _processQueue() async {
    while (_queue.isNotEmpty) {
      PreloadTask? task;

      // 获取下一个任务
      for (var i = 0; i < _queue.length; i++) {
        final t = _queue[i];
        if (!_processingTaskIds.contains(t.taskId)) {
          task = t;
          _queue.removeAt(i);
          break;
        }
      }

      if (task == null) break;

      _processingTaskIds.add(task.taskId);

      // 异步处理任务
      _processTask(task).then((_) {
        _processingTaskIds.remove(task!.taskId);
      });

      // 控制并发数
      while (_processingTaskIds.length >= 3) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    _isProcessingQueue = false;
  }

  /// 处理单个任务
  Future<void> _processTask(PreloadTask task) async {
    await _semaphore.acquire();
    try {
      // 实际处理由外部提供
      // 这里只负责队列管理
      AppLogger.d('Processing preload task: ${task.taskId}', 'MetadataPreloader');
    } finally {
      _semaphore.release();
    }
  }

  /// 清除队列
  void clearQueue() {
    _queue.clear();
    _processingTaskIds.clear();
  }

  // ==================== 统计信息 ====================

  int get queueLength => _queue.length;
  int get processingCount => _processingTaskIds.length;
  int get successCount => _successCount;
  int get errorCount => _errorCount;

  void recordSuccess() => _successCount++;
  void recordError() => _errorCount++;

  Map<String, dynamic> getStatistics() => {
        'queueLength': queueLength,
        'processingCount': processingCount,
        'successCount': _successCount,
        'errorCount': _errorCount,
      };

  void resetStatistics() {
    _successCount = 0;
    _errorCount = 0;
  }
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