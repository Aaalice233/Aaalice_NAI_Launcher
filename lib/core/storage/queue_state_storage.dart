import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';
import '../../data/models/queue/replication_task.dart';
import '../../data/models/queue/failure_handling_strategy.dart';

part 'queue_state_storage.g.dart';

/// 队列执行状态数据
class QueueExecutionStateData {
  final int completedCount;
  final int failedCount;
  final int skippedCount;
  final bool autoExecuteEnabled;
  final double taskIntervalSeconds;
  final FailureHandlingStrategy failureStrategy;
  final bool isPaused;
  final String? currentTaskId;
  final List<String> failedTaskIds;

  const QueueExecutionStateData({
    this.completedCount = 0,
    this.failedCount = 0,
    this.skippedCount = 0,
    this.autoExecuteEnabled = false,
    this.taskIntervalSeconds = 0.0,
    this.failureStrategy = FailureHandlingStrategy.skip,
    this.isPaused = false,
    this.currentTaskId,
    this.failedTaskIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'completedCount': completedCount,
        'failedCount': failedCount,
        'skippedCount': skippedCount,
        'autoExecuteEnabled': autoExecuteEnabled,
        'taskIntervalSeconds': taskIntervalSeconds,
        'failureStrategy': failureStrategy.index,
        'isPaused': isPaused,
        'currentTaskId': currentTaskId,
        'failedTaskIds': failedTaskIds,
      };

  factory QueueExecutionStateData.fromJson(Map<String, dynamic> json) {
    return QueueExecutionStateData(
      completedCount: json['completedCount'] as int? ?? 0,
      failedCount: json['failedCount'] as int? ?? 0,
      skippedCount: json['skippedCount'] as int? ?? 0,
      autoExecuteEnabled: json['autoExecuteEnabled'] as bool? ?? false,
      taskIntervalSeconds:
          (json['taskIntervalSeconds'] as num?)?.toDouble() ?? 0.0,
      failureStrategy:
          FailureHandlingStrategy.values[json['failureStrategy'] as int? ?? 1],
      isPaused: json['isPaused'] as bool? ?? false,
      currentTaskId: json['currentTaskId'] as String?,
      failedTaskIds:
          (json['failedTaskIds'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  QueueExecutionStateData copyWith({
    int? completedCount,
    int? failedCount,
    int? skippedCount,
    bool? autoExecuteEnabled,
    double? taskIntervalSeconds,
    FailureHandlingStrategy? failureStrategy,
    bool? isPaused,
    String? currentTaskId,
    List<String>? failedTaskIds,
  }) {
    return QueueExecutionStateData(
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      autoExecuteEnabled: autoExecuteEnabled ?? this.autoExecuteEnabled,
      taskIntervalSeconds: taskIntervalSeconds ?? this.taskIntervalSeconds,
      failureStrategy: failureStrategy ?? this.failureStrategy,
      isPaused: isPaused ?? this.isPaused,
      currentTaskId: currentTaskId ?? this.currentTaskId,
      failedTaskIds: failedTaskIds ?? this.failedTaskIds,
    );
  }
}

/// 队列执行状态存储服务
/// 注意: Box 在 main.dart 中已预先打开，此处直接同步获取
class QueueStateStorage {
  /// 获取 Box（同步获取已打开的 Box）
  Box<String> get _box => Hive.box<String>(StorageKeys.queueExecutionStateBox);

  /// 保存执行状态
  Future<void> saveExecutionState(QueueExecutionStateData state) async {
    final jsonString = jsonEncode(state.toJson());
    await _box.put(StorageKeys.queueExecutionStateData, jsonString);
  }

  /// 加载执行状态（同步加载）
  QueueExecutionStateData loadExecutionState() {
    try {
      final jsonString = _box.get(StorageKeys.queueExecutionStateData);

      if (jsonString == null || jsonString.isEmpty) {
        return const QueueExecutionStateData();
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return QueueExecutionStateData.fromJson(json);
    } catch (e) {
      return const QueueExecutionStateData();
    }
  }

  /// 保存失败任务列表
  Future<void> saveFailedTasks(List<ReplicationTask> tasks) async {
    final taskList = ReplicationTaskList(tasks: tasks);
    final jsonString = jsonEncode(taskList.toJson());
    await _box.put(StorageKeys.queueFailedTasksData, jsonString);
  }

  /// 加载失败任务列表（同步加载）
  List<ReplicationTask> loadFailedTasks() {
    try {
      final jsonString = _box.get(StorageKeys.queueFailedTasksData);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final taskList = ReplicationTaskList.fromJson(json);
      return taskList.tasks;
    } catch (e) {
      return [];
    }
  }

  /// 清空所有状态
  Future<void> clear() async {
    await _box.clear();
  }
}

/// 队列状态存储服务 Provider
@riverpod
QueueStateStorage queueStateStorage(Ref ref) {
  return QueueStateStorage();
}
