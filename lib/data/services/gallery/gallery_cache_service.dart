import 'dart:collection';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/gallery/local_image_record.dart';

/// 画廊缓存服务
///
/// 实现两层缓存架构：
/// - L1: 内存LRU缓存（热数据，快速访问）
/// - L2: Hive持久化缓存（温数据，应用重启后可用）
class GalleryCacheService {
  /// L1缓存：内存LRU缓存
  final _l1Cache = _LruCache<int, LocalImageRecord>(maxSize: 1000);

  /// L2缓存：Hive持久化
  Box? _l2Cache;

  /// 缓存统计
  int _hits = 0;
  int _misses = 0;

  /// 单例实例
  static final GalleryCacheService instance = GalleryCacheService._();

  GalleryCacheService._();

  /// 初始化缓存
  Future<void> init() async {
    if (_l2Cache != null && _l2Cache!.isOpen) return;

    try {
      _l2Cache = await Hive.openBox('gallery_l2_cache');
      AppLogger.d('Cache service initialized', 'GalleryCacheService');
    } catch (e) {
      AppLogger.w('Failed to open L2 cache: $e', 'GalleryCacheService');
    }
  }

  /// 获取缓存命中率
  double get hitRate {
    final total = _hits + _misses;
    return total > 0 ? _hits / total : 0;
  }

  /// 获取L1缓存大小
  int get l1Size => _l1Cache.length;

  /// 获取L2缓存大小
  int get l2Size => _l2Cache?.length ?? 0;

  /// 获取图片记录（多层缓存策略）
  Future<LocalImageRecord?> get(int imageId) async {
    // 1. 尝试L1缓存
    final l1Result = _l1Cache.get(imageId);
    if (l1Result != null) {
      _hits++;
      return l1Result;
    }

    // 2. 尝试L2缓存
    if (_l2Cache != null) {
      final l2Data = _l2Cache!.get(imageId.toString());
      if (l2Data != null) {
        try {
          final record = _deserializeRecord(l2Data as Map);
          // 提升到L1
          _l1Cache.put(imageId, record);
          _hits++;
          return record;
        } catch (e) {
          // L2数据损坏，删除
          await _l2Cache!.delete(imageId.toString());
        }
      }
    }

    // 3. 缓存未命中
    _misses++;
    return null;
  }

  /// 批量获取
  Future<Map<int, LocalImageRecord>> getMany(List<int> imageIds) async {
    final results = <int, LocalImageRecord>{};

    for (final id in imageIds) {
      final record = await get(id);
      if (record != null) {
        results[id] = record;
      }
    }

    return results;
  }

  /// 放入缓存
  Future<void> put(int imageId, LocalImageRecord record) async {
    // 放入L1
    _l1Cache.put(imageId, record);

    // 异步放入L2
    if (_l2Cache != null) {
      try {
        await _l2Cache!.put(imageId.toString(), _serializeRecord(record));
      } catch (e) {
        AppLogger.w('Failed to write L2 cache: $e', 'GalleryCacheService');
      }
    }
  }

  /// 批量放入缓存
  Future<void> putMany(Map<int, LocalImageRecord> records) async {
    for (final entry in records.entries) {
      await put(entry.key, entry.value);
    }
  }

  /// 使缓存失效
  Future<void> invalidate(int imageId) async {
    _l1Cache.remove(imageId);
    if (_l2Cache != null) {
      await _l2Cache!.delete(imageId.toString());
    }
  }

  /// 批量使缓存失效
  Future<void> invalidateMany(List<int> imageIds) async {
    for (final id in imageIds) {
      await invalidate(id);
    }
  }

  /// 预热缓存（预加载数据）
  Future<void> warmUp(List<LocalImageRecord> records) async {
    for (final record in records) {
      // 使用路径哈希作为临时ID（实际使用时应该使用数据库ID）
      final tempId = record.path.hashCode;
      _l1Cache.put(tempId, record);
    }
  }

  /// 清空L1缓存
  void clearL1() {
    _l1Cache.clear();
    _hits = 0;
    _misses = 0;
  }

  /// 清空所有缓存
  Future<void> clearAll() async {
    _l1Cache.clear();
    if (_l2Cache != null) {
      await _l2Cache!.clear();
    }
    _hits = 0;
    _misses = 0;
    AppLogger.d('All caches cleared', 'GalleryCacheService');
  }

  /// 序列化记录
  Map<String, dynamic> _serializeRecord(LocalImageRecord record) {
    return {
      'path': record.path,
      'size': record.size,
      'modifiedAt': record.modifiedAt.millisecondsSinceEpoch,
      'isFavorite': record.isFavorite,
      'tags': record.tags,
      'metadataStatus': record.metadataStatus.index,
      if (record.metadata != null) 'metadata': record.metadata!.toJson(),
    };
  }

  /// 反序列化记录
  LocalImageRecord _deserializeRecord(Map data) {
    return LocalImageRecord(
      path: data['path'] as String,
      size: data['size'] as int,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(data['modifiedAt'] as int),
      isFavorite: data['isFavorite'] as bool? ?? false,
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
      metadataStatus: MetadataStatus.values[data['metadataStatus'] as int? ?? 0],
    );
  }
}

/// LRU缓存实现
class _LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  _LruCache({required this.maxSize});

  int get length => _cache.length;

  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      // 移到队尾（最近使用）
      _cache[key] = value;
    }
    return value;
  }

  void put(K key, V value) {
    _cache.remove(key);
    _cache[key] = value;

    // 超出限制时淘汰最旧条目
    while (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  void remove(K key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  bool containsKey(K key) => _cache.containsKey(key);
}
