import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mutex/mutex.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/tag/tag_task.dart';
import '../../utils/app_logger.dart';

part 'tag_task_scheduler.g.dart';

/// 标签任务调度器 Provider
@Riverpod(keepAlive: true)
TagTaskScheduler tagTaskScheduler(Ref ref) {
  return TagTaskScheduler();
}

/// 标签任务调度器
///
/// 使用互斥锁实现任务队列的互斥访问，确保同一时间只有一个任务在执行。
/// 艺术家标签任务排队在常规标签任务之后。
class TagTaskScheduler {
  final Mutex _mutex = Mutex();
  final List<TagTask> _taskQueue = [];

  /// 获取当前任务队列（只读副本）
  List<TagTask> get tasks => List.unmodifiable(_taskQueue);

  /// 获取当前正在运行的任务
  TagTask? get runningTask {
    try {
      return _taskQueue.firstWhere(
        (task) => task.status == TagTaskStatus.running,
      );
    } catch (_) {
      return null;
    }
  }

  /// 获取等待中的任务
  List<TagTask> get pendingTasks =>
      _taskQueue.where((task) => task.status == TagTaskStatus.pending).toList();

  /// 获取活跃任务数量
  int get activeTaskCount =>
      _taskQueue.where((task) => task.isActive).length;

  /// 添加任务到队列
  ///
  /// 如果是艺术家任务，会排在所有常规任务之后。
  /// 如果是常规任务，会按 FIFO 顺序排在队列末尾。
  Future<TagTask> enqueue(TagTask task) async {
    return await _mutex.protect(() async {
      // 检查是否已存在相同 ID 的任务
      if (_taskQueue.any((t) => t.id == task.id)) {
        AppLogger.w('Task with ID ${task.id} already exists in queue', 'TAG_TASK_SCHEDULER');
        return _taskQueue.firstWhere((t) => t.id == task.id);
      }

      // 根据任务类型决定插入位置
      if (task.type == TagTaskType.artist) {
        // 艺术家任务：找到最后一个常规任务之后，或队列末尾
        final lastRegularIndex = _taskQueue.lastIndexWhere(
          (t) => t.type == TagTaskType.regular && t.isActive,
        );
        if (lastRegularIndex == -1) {
          _taskQueue.add(task);
        } else {
          _taskQueue.insert(lastRegularIndex + 1, task);
        }
      } else {
        // 常规任务：添加到队列末尾
        _taskQueue.add(task);
      }

      AppLogger.d('Enqueued ${task.type.name} task ${task.id}, queue size: ${_taskQueue.length}', 'TAG_TASK_SCHEDULER');
      return task;
    });
  }

  /// 从队列中移除任务
  ///
  /// 如果任务正在运行，会触发取消操作。
  /// 如果任务已完成，则不会移除。
  Future<bool> remove(String taskId) async {
    return await _mutex.protect(() async {
      final index = _taskQueue.indexWhere((t) => t.id == taskId);
      if (index == -1) {
        AppLogger.w('Task $taskId not found in queue', 'TAG_TASK_SCHEDULER');
        return false;
      }

      final task = _taskQueue[index];

      // 如果任务已完成，不移除
      if (task.isCompleted) {
        AppLogger.d('Task $taskId is already completed, not removing', 'TAG_TASK_SCHEDULER');
        return false;
      }

      // 如果任务正在运行，取消它
      if (task.status == TagTaskStatus.running) {
        AppLogger.d('Cancelling running task $taskId', 'TAG_TASK_SCHEDULER');
        task.cancel('任务被取消');
      }

      _taskQueue.removeAt(index);
      AppLogger.d('Removed task $taskId from queue', 'TAG_TASK_SCHEDULER');
      return true;
    });
  }

  /// 获取下一个待执行的任务
  ///
  /// 按照优先级返回下一个 pending 状态的任务。
  /// 由于 enqueue 已经处理了排序，这里直接返回第一个 pending 任务。
  Future<TagTask?> nextTask() async {
    return await _mutex.protect(() async {
      try {
        return _taskQueue.firstWhere(
          (task) => task.status == TagTaskStatus.pending,
        );
      } catch (_) {
        return null;
      }
    });
  }

  /// 标记任务为运行中
  Future<bool> markAsRunning(String taskId) async {
    return await _mutex.protect(() async {
      final index = _taskQueue.indexWhere((t) => t.id == taskId);
      if (index == -1) {
        AppLogger.w('Cannot mark running: task $taskId not found', 'TAG_TASK_SCHEDULER');
        return false;
      }

      final task = _taskQueue[index];
      if (task.status != TagTaskStatus.pending) {
        AppLogger.w('Cannot mark running: task $taskId is not pending (${task.status})', 'TAG_TASK_SCHEDULER');
        return false;
      }

      // 使用 copyWith 创建新实例，更新状态
      final updatedTask = task.copyWith(
        status: TagTaskStatus.running,
        startedAt: DateTime.now(),
      );
      _taskQueue[index] = updatedTask;

      AppLogger.d('Marked task $taskId as running', 'TAG_TASK_SCHEDULER');
      return true;
    });
  }

  /// 标记任务为完成
  Future<bool> markAsCompleted(String taskId, {String? error}) async {
    return await _mutex.protect(() async {
      final index = _taskQueue.indexWhere((t) => t.id == taskId);
      if (index == -1) {
        AppLogger.w('Cannot mark completed: task $taskId not found', 'TAG_TASK_SCHEDULER');
        return false;
      }

      final task = _taskQueue[index];

      TagTaskStatus newStatus;
      if (error != null) {
        newStatus = TagTaskStatus.failed;
      } else if (task.status == TagTaskStatus.cancelled) {
        // 保持取消状态
        newStatus = TagTaskStatus.cancelled;
      } else {
        newStatus = TagTaskStatus.completed;
      }

      final updatedTask = task.copyWith(
        status: newStatus,
        error: error,
        completedAt: DateTime.now(),
        progress: error != null ? task.progress : 1.0,
      );
      _taskQueue[index] = updatedTask;

      AppLogger.d('Marked task $taskId as ${newStatus.name}${error != null ? " (error: $error)" : ""}', 'TAG_TASK_SCHEDULER');
      return true;
    });
  }

  /// 标记任务为已取消
  Future<bool> markAsCancelled(String taskId, [String? reason]) async {
    return await _mutex.protect(() async {
      final index = _taskQueue.indexWhere((t) => t.id == taskId);
      if (index == -1) {
        AppLogger.w('Cannot mark cancelled: task $taskId not found', 'TAG_TASK_SCHEDULER');
        return false;
      }

      final task = _taskQueue[index];
      if (task.isCompleted) {
        AppLogger.w('Cannot mark cancelled: task $taskId is already completed', 'TAG_TASK_SCHEDULER');
        return false;
      }

      // 取消网络请求
      task.cancel(reason ?? '任务被取消');

      final updatedTask = task.copyWith(
        status: TagTaskStatus.cancelled,
        completedAt: DateTime.now(),
      );
      _taskQueue[index] = updatedTask;

      AppLogger.d('Marked task $taskId as cancelled${reason != null ? " (reason: $reason)" : ""}', 'TAG_TASK_SCHEDULER');
      return true;
    });
  }

  /// 更新任务进度
  Future<bool> updateProgress(String taskId, double progress) async {
    return await _mutex.protect(() async {
      final index = _taskQueue.indexWhere((t) => t.id == taskId);
      if (index == -1) {
        return false;
      }

      final task = _taskQueue[index];
      if (task.status != TagTaskStatus.running) {
        return false;
      }

      final clampedProgress = progress.clamp(0.0, 1.0);
      final updatedTask = task.copyWith(progress: clampedProgress);
      _taskQueue[index] = updatedTask;

      return true;
    });
  }

  /// 清理已完成的任务
  ///
  /// [maxAge] 指定保留已完成任务的最长时间，超过该时间的任务将被移除。
  /// 如果为 null，则保留所有已完成任务。
  Future<int> cleanupCompleted({Duration? maxAge}) async {
    return await _mutex.protect(() async {
      final initialCount = _taskQueue.length;

      _taskQueue.removeWhere((task) {
        if (!task.isCompleted) return false;
        if (maxAge == null) return false;
        if (task.completedAt == null) return false;

        final age = DateTime.now().difference(task.completedAt!);
        return age > maxAge;
      });

      final removedCount = initialCount - _taskQueue.length;
      if (removedCount > 0) {
        AppLogger.d('Cleaned up $removedCount completed tasks', 'TAG_TASK_SCHEDULER');
      }
      return removedCount;
    });
  }

  /// 清空所有任务
  ///
  /// 会取消所有正在运行的任务。
  Future<void> clear() async {
    await _mutex.protect(() async {
      // 取消所有正在运行的任务
      for (final task in _taskQueue) {
        if (task.status == TagTaskStatus.running) {
          task.cancel('调度器清空');
        }
      }
      _taskQueue.clear();
      AppLogger.d('Cleared all tasks', 'TAG_TASK_SCHEDULER');
    });
  }

  /// 取消所有指定类型的任务
  Future<int> cancelByType(TagTaskType type, [String? reason]) async {
    return await _mutex.protect(() async {
      int count = 0;
      for (var i = 0; i < _taskQueue.length; i++) {
        final task = _taskQueue[i];
        if (task.type == type && !task.isCompleted) {
          if (task.status == TagTaskStatus.running) {
            task.cancel(reason ?? '批量取消');
          }
          _taskQueue[i] = task.copyWith(
            status: TagTaskStatus.cancelled,
            completedAt: DateTime.now(),
          );
          count++;
        }
      }

      if (count > 0) {
        AppLogger.d('Cancelled $count tasks of type ${type.name}', 'TAG_TASK_SCHEDULER');
      }
      return count;
    });
  }
}
