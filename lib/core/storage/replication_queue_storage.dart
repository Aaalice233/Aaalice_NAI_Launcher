import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';
import '../../data/models/queue/replication_task.dart';

part 'replication_queue_storage.g.dart';

/// 复刻队列存储服务
///
/// 使用独立的 Hive Box 存储队列数据，以 JSON 字符串形式保存
class ReplicationQueueStorage {
  Box<String>? _box;

  /// 获取队列 Box（懒加载）
  Future<Box<String>> _getBox() async {
    _box ??= await Hive.openBox<String>(StorageKeys.replicationQueueBox);
    return _box!;
  }

  /// 保存队列到本地存储
  Future<void> save(List<ReplicationTask> tasks) async {
    final box = await _getBox();
    final taskList = ReplicationTaskList(tasks: tasks);
    final jsonString = jsonEncode(taskList.toJson());
    await box.put(StorageKeys.replicationQueueData, jsonString);
  }

  /// 从本地存储加载队列
  Future<List<ReplicationTask>> load() async {
    try {
      final box = await _getBox();
      final jsonString = box.get(StorageKeys.replicationQueueData);

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
  Future<void> clear() async {
    final box = await _getBox();
    await box.delete(StorageKeys.replicationQueueData);
  }
}

/// 复刻队列存储服务 Provider
@riverpod
ReplicationQueueStorage replicationQueueStorage(Ref ref) {
  return ReplicationQueueStorage();
}
