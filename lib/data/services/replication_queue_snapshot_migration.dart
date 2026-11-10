import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/replication_queue_blob_store.dart';
import '../../core/storage/replication_queue_startup_gate.dart';
import '../../core/storage/storage_file_system.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/hive_startup_box_opener.dart';
import '../models/queue/replication_task_generation_snapshot.dart';
import '../models/queue/replication_task_snapshot_blobs.dart';

/// 在主壳与执行器读取队列索引前完成迁移，再打开启动闸门。
Future<void> prepareReplicationQueue({
  required String hivePath,
  required ReplicationQueueBlobStore blobStore,
}) async {
  try {
    await Future.wait([
      HiveStartupBoxOpener.openBox<String>(
        StorageKeys.replicationQueueBox,
        hivePath: hivePath,
      ),
      HiveStartupBoxOpener.openBox<String>(
        StorageKeys.queueExecutionStateBox,
        hivePath: hivePath,
      ),
    ]);
    await ReplicationQueueSnapshotMigration(
      queueBox: Hive.box<String>(StorageKeys.replicationQueueBox),
      stateBox: Hive.box<String>(StorageKeys.queueExecutionStateBox),
      blobStore: blobStore,
    ).run();
  } finally {
    ReplicationQueueStartupGate.open();
  }
}

/// 一份索引的迁移结果；[index] 为 null 表示没有需要改写的快照，
/// [digests] 为 null 表示索引读不懂、无法确定它引用了哪些图片。
typedef _IndexMigration = ({
  String? index,
  List<String>? digests,
  int converted,
  int kept,
});

typedef _SlotText = ({bool vibeEncoding, String text});

class ReplicationQueueMigrationResult {
  const ReplicationQueueMigrationResult({
    required this.converted,
    required this.kept,
    required this.collected,
  });

  final int converted;
  final int kept;
  final int collected;
}

/// 启动时把队列与失败池中 v1 快照的内联图片迁移为内容寻址文件，并压缩两个 box。
///
/// 按快照自身的版本号逐条判定，可重复执行；任何一步失败都保留原索引。
class ReplicationQueueSnapshotMigration {
  ReplicationQueueSnapshotMigration({
    required Box<String> queueBox,
    required Box<String> stateBox,
    required ReplicationQueueBlobStore blobStore,
  }) : _queueBox = queueBox,
       _stateBox = stateBox,
       _blobStore = blobStore;

  static const int _legacySchemaVersion = 1;
  static const String _tag = 'QueueMigration';

  final Box<String> _queueBox;
  final Box<String> _stateBox;
  final ReplicationQueueBlobStore _blobStore;

  /// 迁移失败只记日志，索引保持原样可读，下次启动重试。
  Future<ReplicationQueueMigrationResult?> run() async {
    try {
      final result = await _run();
      if (result.converted > 0 || result.kept > 0 || result.collected > 0) {
        AppLogger.i(
          'Queue snapshots migrated: ${result.converted}, left as is: '
          '${result.kept}, image files collected: ${result.collected}',
          _tag,
        );
      }
      return result;
    } catch (error) {
      AppLogger.w(
        'Queue snapshot migration failed; keeping the existing index '
        '(${error is QueueBlobWriteException ? error : error.runtimeType})',
        _tag,
      );
      return null;
    }
  }

  Future<ReplicationQueueMigrationResult> _run() async {
    Set<String>? digests = <String>{};
    var converted = 0;
    var kept = 0;
    for (final (box, key) in [
      (_queueBox, StorageKeys.replicationQueueData),
      (_stateBox, StorageKeys.queueFailedTasksData),
    ]) {
      final original = box.get(key);
      if (original == null || original.isEmpty) continue;
      final migration = await _blobStore.runOnWorker(
        'QueueMigration.index',
        original,
        _migrateIndex,
      );
      converted += migration.converted;
      kept += migration.kept;
      final index = migration.index;
      // 迁移期间若有人改写了这份索引，以对方为准，下次启动再迁移
      final deferred = !identical(box.get(key), original);
      if (index != null && !deferred) {
        await box.put(key, index);
      }
      final indexDigests = migration.digests;
      // 改写后的索引可能引用这次没算进根集合的图片
      if (indexDigests == null || deferred) {
        digests = null;
      } else {
        digests?.addAll(indexDigests);
      }
    }
    await _queueBox.compact();
    await _stateBox.compact();
    final roots = _sweepRoots(digests);
    final collected = roots == null ? 0 : await _blobStore.collect(() => roots);
    return ReplicationQueueMigrationResult(
      converted: converted,
      kept: kept,
      collected: collected,
    );
  }

  static Set<String>? _sweepRoots(Set<String>? digests) {
    if (ReplicationQueueStartupGate.readWhileClosed) {
      // 迁移前读过索引的一方稍后保存时，可能引用这份根集合之外的图片
      AppLogger.w(
        'Queue index was read before migration; skipping the sweep',
        _tag,
      );
      return null;
    }
    if (digests == null) {
      AppLogger.w('Queue index not fully understood; skipping the sweep', _tag);
    }
    return digests;
  }

  static Future<_IndexMigration> _migrateIndex(
    StorageFileSystem fileSystem,
    String directory,
    String original,
  ) async {
    const unreadable = (index: null, digests: null, converted: 0, kept: 0);
    final Object? decoded;
    try {
      decoded = jsonDecode(original);
    } on FormatException {
      return unreadable;
    }
    final tasks = decoded is Map ? decoded['tasks'] : null;
    if (tasks is! List) return unreadable;
    final stored = <_SlotText, Map<String, dynamic>>{};
    var directoryReady = false;
    var converted = 0;
    var kept = 0;
    var unknownVersion = false;
    for (final task in tasks) {
      if (task is! Map) continue;
      final snapshot = task['generationSnapshot'];
      if (snapshot is! Map<String, dynamic>) continue;
      if (!ReplicationTaskGenerationSnapshot.isKnownVersion(snapshot)) {
        unknownVersion = true;
        continue;
      }
      if (snapshot['schemaVersion'] != _legacySchemaVersion) continue;
      final Map<String, dynamic> lifted;
      final pending = <_SlotText, Uint8List>{};
      try {
        lifted = _liftLegacy(snapshot);
        for (final (slot, value) in SnapshotBlobSlots.entries(lifted)) {
          final key = _slotText(value, slot);
          if (!stored.containsKey(key) && !pending.containsKey(key)) {
            pending[key] = key.vibeEncoding
                ? utf8.encode(key.text)
                : base64Decode(key.text);
          }
        }
      } on FormatException {
        // 单条损坏只保留该条原样，执行时按无效快照进失败池
        kept++;
        continue;
      }
      if (pending.isNotEmpty && !directoryReady) {
        await fileSystem.createDirectory(directory);
        directoryReady = true;
      }
      for (final MapEntry(:key, value: bytes) in pending.entries) {
        final digest = sha256.convert(bytes).toString();
        await ReplicationQueueBlobStore.storeBlob(
          fileSystem,
          directory,
          digest,
          bytes,
        );
        stored[key] = QueueBlobRef(digest, bytes.length).toJson();
      }
      task['generationSnapshot'] = SnapshotBlobSlots.map(
        lifted,
        (value, slot) => stored[_slotText(value, slot)]!,
      );
      converted++;
    }
    final digests = unknownVersion
        ? null
        : <String>{
            for (final task in tasks)
              if (task is Map)
                ...ReplicationTaskGenerationSnapshot.blobDigests(
                  task['generationSnapshot'],
                ),
          }.toList();
    return (
      index: converted == 0 ? null : jsonEncode(decoded),
      digests: digests,
      converted: converted,
      kept: kept,
    );
  }

  /// Vibe 编码按原文存字节，其余槽位是 base64；同一段文本在两类槽位里对应不同的字节。
  static _SlotText _slotText(Object value, String slot) {
    if (value is! String) throw const FormatException('Invalid image data');
    return (vibeEncoding: slot == SnapshotBlobSlots.vibeEncoding, text: value);
  }

  /// v1 的槽位是 base64 文本、Vibe 编码内联在 value 里；改成 v2 的槽位布局，槽位仍是文本。
  static Map<String, dynamic> _liftLegacy(Map<String, dynamic> legacy) {
    final lifted = Map<String, dynamic>.of(legacy)
      ..['schemaVersion'] = ReplicationTaskGenerationSnapshot.schemaVersion;
    final vibes = lifted[SnapshotBlobSlots.vibeReferences];
    if (vibes is List) {
      lifted[SnapshotBlobSlots.vibeReferences] = [
        for (final item in vibes)
          item is Map<String, dynamic> && item['value'] is Map<String, dynamic>
              ? _liftVibe(item)
              : item,
      ];
    }
    return lifted;
  }

  static Map<String, dynamic> _liftVibe(Map<String, dynamic> item) {
    final value = item['value'] as Map<String, dynamic>;
    final encoding = value[vibeReferenceEncodingField];
    if (encoding is! String || encoding.isEmpty) return item;
    return {
      ...item,
      'value': {...value, vibeReferenceEncodingField: ''},
      SnapshotBlobSlots.vibeEncoding: encoding,
    };
  }
}
