import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/storage_keys.dart';
import '../utils/app_logger.dart';
import '../../data/models/queue/replication_task.dart';
import 'base_hive_storage.dart';

part 'replication_queue_storage.g.dart';

/// 复刻队列存储服务
///
/// 使用独立的 Hive Box 存储队列数据，以 JSON 字符串形式保存。
/// 生成快照中的大体积字符串（源图、遮罩、参考图等 base64）按内容哈希单独
/// 保存在 [StorageKeys.replicationQueueBlobBox]，队列 JSON 只保留引用：
/// 同一张图被多个任务共用时只写入一份，任务状态变化也不再重写图像。
/// 注意: Box 在启动初始化中已预先打开，此处直接同步获取
class ReplicationQueueStorage extends BaseHiveStorage<void> {
  ReplicationQueueStorage()
    : super(boxName: StorageKeys.replicationQueueBox, useLazyLoading: false);

  /// 达到该长度的快照字符串外置保存；提示词等短文本保持内联。
  static const int _blobThreshold = 16 * 1024;
  static const String _blobReferencePrefix = 'queue-blob:sha256:';

  /// 按字符串实例缓存哈希，同一份图像数据只计算一次。
  Map<String, String> _hashByValue = HashMap.identity();

  Box<String> get _queueBox =>
      Hive.box<String>(StorageKeys.replicationQueueBox);

  Box<String> get _blobBox =>
      Hive.box<String>(StorageKeys.replicationQueueBlobBox);

  /// 保存队列到本地存储
  ///
  /// 依次写入新图像、队列 JSON、清理无引用图像；任一步中断都不会留下
  /// 引用缺失图像的任务。
  Future<void> save(List<ReplicationTask> tasks) async {
    final blobs = <String, String>{};
    final hashByValue = HashMap<String, String>.identity();
    final taskJson = [
      for (final task in tasks)
        _mapSnapshot(task.toJson(), (value) {
          return _externalize(value, blobs, hashByValue);
        }),
    ];
    _hashByValue = hashByValue;

    final newBlobs = {
      for (final entry in blobs.entries)
        if (!_blobBox.containsKey(entry.key)) entry.key: entry.value,
    };
    if (newBlobs.isNotEmpty) await _blobBox.putAll(newBlobs);
    await _queueBox.put(
      StorageKeys.replicationQueueData,
      jsonEncode({'tasks': taskJson}),
    );
    final staleKeys = _blobBox.keys
        .where((key) => !blobs.containsKey(key))
        .toList();
    if (staleKeys.isNotEmpty) await _blobBox.deleteAll(staleKeys);
  }

  /// 从本地存储加载队列（同步加载）
  ///
  /// 兼容旧版内嵌图像的格式；引用图像缺失的任务会被跳过。
  List<ReplicationTask> load() {
    try {
      final jsonString = _queueBox.get(StorageKeys.replicationQueueData);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final hashByValue = HashMap<String, String>.identity();
      final tasks = <ReplicationTask>[];
      for (final taskJson in json['tasks'] as List? ?? const []) {
        final resolved = _resolveTask(
          taskJson as Map<String, dynamic>,
          hashByValue,
        );
        if (resolved != null) tasks.add(ReplicationTask.fromJson(resolved));
      }
      _hashByValue = hashByValue;
      return tasks;
    } catch (error, stackTrace) {
      AppLogger.e('Failed to restore replication queue', error, stackTrace);
      return [];
    }
  }

  /// 估算这些快照按当前格式持久化后的总字节数，内容相同的图像只计一次。
  static int estimatePersistedSnapshotBytes(
    Iterable<Map<String, dynamic>> snapshots,
  ) {
    final reference = '$_blobReferencePrefix${'0' * 64}';
    final countedBlobs = HashSet<String>();
    var total = 0;
    for (final snapshot in snapshots) {
      final compact = _mapStrings(snapshot, (value) {
        if (value.length < _blobThreshold) return value;
        if (countedBlobs.add(value)) total += utf8.encode(value).length;
        return reference;
      });
      total += utf8.encode(jsonEncode(compact)).length;
    }
    return total;
  }

  /// 清空存储
  @override
  Future<void> clear() async {
    await _queueBox.delete(StorageKeys.replicationQueueData);
    await _blobBox.clear();
    _hashByValue = HashMap.identity();
  }

  String _externalize(
    String value,
    Map<String, String> blobs,
    Map<String, String> hashByValue,
  ) {
    if (value.length < _blobThreshold) return value;
    final hash = hashByValue[value] ??=
        _hashByValue[value] ?? sha256.convert(utf8.encode(value)).toString();
    blobs[hash] = value;
    return '$_blobReferencePrefix$hash';
  }

  /// 返回 null 表示该任务引用的图像已缺失。
  Map<String, dynamic>? _resolveTask(
    Map<String, dynamic> json,
    Map<String, String> hashByValue,
  ) {
    try {
      return _mapSnapshot(json, (value) {
        if (!value.startsWith(_blobReferencePrefix)) return value;
        final hash = value.substring(_blobReferencePrefix.length);
        final blob = _blobBox.get(hash);
        if (blob == null) throw _MissingQueueBlob(hash);
        hashByValue[blob] = hash;
        return blob;
      });
    } on _MissingQueueBlob catch (missing) {
      AppLogger.w(
        'Skipped queue task ${json['id']}: missing image ${missing.hash}',
        'ReplicationQueue',
      );
      return null;
    }
  }

  /// 仅转换任务 JSON 中 generationSnapshot 内的字符串，返回新的 Map。
  static Map<String, dynamic> _mapSnapshot(
    Map<String, dynamic> taskJson,
    String Function(String value) convert,
  ) {
    final snapshot = taskJson['generationSnapshot'];
    if (snapshot == null) return taskJson;
    return {...taskJson, 'generationSnapshot': _mapStrings(snapshot, convert)};
  }

  static Object? _mapStrings(
    Object? value,
    String Function(String value) convert,
  ) {
    return switch (value) {
      final String text => convert(text),
      final Map<dynamic, dynamic> map => <String, dynamic>{
        for (final entry in map.entries)
          entry.key as String: _mapStrings(entry.value, convert),
      },
      final List<dynamic> list => [
        for (final item in list) _mapStrings(item, convert),
      ],
      _ => value,
    };
  }
}

class _MissingQueueBlob implements Exception {
  const _MissingQueueBlob(this.hash);

  final String hash;
}

/// 复刻队列存储服务 Provider
@riverpod
ReplicationQueueStorage replicationQueueStorage(Ref ref) {
  return ReplicationQueueStorage();
}
