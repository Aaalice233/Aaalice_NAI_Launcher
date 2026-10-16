import 'dart:io';
import 'dart:math' as math;

import 'package:hive/hive.dart';

import 'metadata_cache_entry_codec.dart';

class MetadataCacheEvictionResult {
  const MetadataCacheEvictionResult({
    required this.bytesBefore,
    required this.bytesAfter,
    required this.scannedEntries,
    required this.evictedEntries,
  });

  final int bytesBefore;
  final int bytesAfter;
  final int scannedEntries;
  final int evictedEntries;
}

/// 按写入时间淘汰 L2 元数据缓存最旧的条目，使 box 文件降到目标大小以下。
///
/// 懒加载 box 的值不在内存里：扫描逐条异步读值，只留下键、写入时间与权重，
/// 值读完即丢弃，也不解码元数据 JSON；扫描与删除都分批并让出事件循环。
class MetadataCacheEvictor {
  const MetadataCacheEvictor({this.batchSize = 500});

  final int batchSize;

  // Hive 帧固定开销：帧长 4 + 键类型与长度 2 + 值类型 1 + 字符串长度 4 + CRC 4
  static const int _frameOverheadBytes = 15;

  /// box 在磁盘上的文件字节数；内存 box 或文件不存在时为 0
  static Future<int> fileBytes(BoxBase<Object?> box) async {
    final path = box.isOpen ? box.path : null;
    if (path == null) return 0;
    final stat = await FileStat.stat(path);
    return stat.type == FileSystemEntityType.file ? stat.size : 0;
  }

  Future<MetadataCacheEvictionResult> evictToTarget(
    LazyBox<String> box, {
    required int targetBytes,
  }) async {
    final bytesBefore = await fileBytes(box);
    if (bytesBefore <= targetBytes) {
      return _unchanged(bytesBefore);
    }

    // 先回收失效帧，文件大小才等于存活条目的真实占用
    await box.compact();
    final liveBytes = await fileBytes(box);
    if (liveBytes <= targetBytes) {
      return MetadataCacheEvictionResult(
        bytesBefore: bytesBefore,
        bytesAfter: liveBytes,
        scannedEntries: 0,
        evictedEntries: 0,
      );
    }

    final entries = await _scan(box);
    final victims = _selectOldest(
      entries,
      liveBytes: liveBytes,
      targetBytes: targetBytes,
    );
    final evicted = await _delete(box, victims);
    if (evicted > 0) await box.compact();

    return MetadataCacheEvictionResult(
      bytesBefore: bytesBefore,
      bytesAfter: await fileBytes(box),
      scannedEntries: entries.length,
      evictedEntries: evicted,
    );
  }

  MetadataCacheEvictionResult _unchanged(int bytes) =>
      MetadataCacheEvictionResult(
        bytesBefore: bytes,
        bytesAfter: bytes,
        scannedEntries: 0,
        evictedEntries: 0,
      );

  Future<List<_CachedEntry>> _scan(LazyBox<String> box) async {
    // 先取键快照：读值期间的写入不会打断遍历
    final keys = box.keys
        .whereType<String>()
        .where((key) => !key.startsWith('_'))
        .toList(growable: false);
    final entries = <_CachedEntry>[];
    for (var index = 0; index < keys.length; index++) {
      final key = keys[index];
      final raw = await box.get(key);
      if (raw != null) {
        entries.add(
          _CachedEntry(
            key: key,
            writtenAtMillis: MetadataCacheEntryCodec.writtenAtMillisOf(raw),
            weight: key.length + raw.length + _frameOverheadBytes,
          ),
        );
      }
      if ((index + 1) % batchSize == 0) await _yieldToEventLoop();
    }
    return entries;
  }

  List<_CachedEntry> _selectOldest(
    List<_CachedEntry> entries, {
    required int liveBytes,
    required int targetBytes,
  }) {
    final totalWeight = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.weight,
    );
    if (totalWeight == 0) return const [];

    // 字符数到磁盘字节的换算以压缩后的真实文件为准，吸收 UTF-8 多字节差异
    final weightToFree = (liveBytes - targetBytes) * totalWeight / liveBytes;
    entries.sort(_CachedEntry.compareByAge);
    final victims = <_CachedEntry>[];
    var freedWeight = 0;
    for (final entry in entries) {
      if (freedWeight >= weightToFree) break;
      victims.add(entry);
      freedWeight += entry.weight;
    }
    return victims;
  }

  Future<int> _delete(LazyBox<String> box, List<_CachedEntry> victims) async {
    var evicted = 0;
    for (var start = 0; start < victims.length; start += batchSize) {
      final end = math.min(start + batchSize, victims.length);
      final keys = <String>[];
      for (var index = start; index < end; index++) {
        final victim = victims[index];
        final raw = await box.get(victim.key);
        // 扫描后被重新写入的条目已是新数据，不再淘汰
        if (raw != null &&
            MetadataCacheEntryCodec.writtenAtMillisOf(raw) ==
                victim.writtenAtMillis) {
          keys.add(victim.key);
        }
      }
      if (keys.isNotEmpty) {
        await box.deleteAll(keys);
        evicted += keys.length;
      }
      await _yieldToEventLoop();
    }
    return evicted;
  }

  static Future<void> _yieldToEventLoop() =>
      Future<void>.delayed(Duration.zero);
}

final class _CachedEntry {
  const _CachedEntry({
    required this.key,
    required this.writtenAtMillis,
    required this.weight,
  });

  final String key;
  final int writtenAtMillis;
  final int weight;

  static int compareByAge(_CachedEntry a, _CachedEntry b) {
    final byTime = a.writtenAtMillis.compareTo(b.writtenAtMillis);
    return byTime != 0 ? byTime : a.key.compareTo(b.key);
  }
}
