import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';
import '../../data/models/queue/replication_task.dart';
import 'base_hive_storage.dart';

part 'replication_queue_storage.g.dart';

/// 复刻队列存储服务
///
/// 使用独立的 Hive Box 存储队列数据，以 JSON 字符串形式保存
/// 注意: Box 在 main.dart 中已预先打开，此处直接同步获取
class ReplicationQueueStorage extends BaseHiveStorage<void> {
  ReplicationQueueStorage()
    : super(boxName: StorageKeys.replicationQueueBox, useLazyLoading: false);

  /// 保存队列到本地存储
  Future<void> save(List<ReplicationTask> tasks) async {
    final taskList = ReplicationTaskList(tasks: tasks);
    final jsonString = jsonEncode(taskList.toJson());
    await box.put(StorageKeys.replicationQueueData, jsonString);
  }

  /// 从本地存储加载队列（同步加载）
  List<ReplicationTask> load() {
    try {
      final jsonString = box.get(StorageKeys.replicationQueueData) as String?;

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final taskList = ReplicationTaskList.fromJson(json);
      return taskList.tasks;
    } catch (e) {
      // 加载失败时返回空列表
      return [];
    }
  }

  /// 清空存储
  @override
  Future<void> clear() async {
    await box.delete(StorageKeys.replicationQueueData);
  }
}

/// 复刻队列存储服务 Provider
@riverpod
ReplicationQueueStorage replicationQueueStorage(Ref ref) {
  return ReplicationQueueStorage();
}
