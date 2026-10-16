import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'metadata_cache_entry_codec.dart';

/// 元数据缓存管理器
///
/// 管理两层缓存：
/// - L1: 内存缓存 (LRU)
/// - L2: Hive 持久化缓存，懒加载 box 只在内存中保留键
class MetadataCacheManager {
  static final MetadataCacheManager _instance =
      MetadataCacheManager._internal();
  factory MetadataCacheManager() => _instance;
  MetadataCacheManager._internal();

  static const int _memoryCacheCapacity = 500;
  // Bump this whenever NaiImageMetadata parsing semantics change; cached values
  // are parsed snapshots, not raw PNG metadata.
  static const int _currentCacheVersion = 8;
  static const String _versionKey = '_cacheVersion';

  LazyBox<String>? _persistentBox;
  final _memoryCache = _LRUCache<String, _MemoryEntry>(
    capacity: _memoryCacheCapacity,
  );

  // 统计计数器
  int _memoryCacheHits = 0;
  int _memoryCacheMisses = 0;
  int _persistentCacheHits = 0;
  int _persistentCacheMisses = 0;

  /// 初始化缓存管理器
  Future<void> initialize() async {
    if (_persistentBox != null && _persistentBox!.isOpen) return;

    try {
      _persistentBox = Hive.isBoxOpen(StorageKeys.localMetadataCacheBox)
          ? Hive.lazyBox<String>(StorageKeys.localMetadataCacheBox)
          : await Hive.openLazyBox<String>(StorageKeys.localMetadataCacheBox);

      await _migrateCacheIfNeeded();

      AppLogger.i(
        'MetadataCacheManager initialized: persistent cache has ${_persistentBox!.length} entries',
        'MetadataCacheManager',
      );
    } catch (e) {
      AppLogger.e(
        'Failed to initialize MetadataCacheManager',
        e,
        null,
        'MetadataCacheManager',
      );
      rethrow;
    }
  }

  /// 从 L1 内存缓存获取
  NaiImageMetadata? getFromMemory(String hash) {
    final entry = _memoryCache.get(hash);
    if (entry != null) {
      _memoryCacheHits++;
      final metadata = entry.metadata;
      final upgraded = metadata.upgradeFromRawJsonIfNeeded();
      if (!identical(upgraded, metadata)) {
        _memoryCache.put(hash, _MemoryEntry(upgraded, entry.serializedLength));
      }
      return upgraded;
    }
    _memoryCacheMisses++;
    return null;
  }

  /// 从 L2 持久化缓存获取，命中后放入 L1
  Future<NaiImageMetadata?> getFromPersistent(String hash) async {
    try {
      final raw = await _getBox().get(hash);
      final jsonString = raw == null
          ? null
          : MetadataCacheEntryCodec.metadataJsonOf(raw);
      if (jsonString == null) {
        _persistentCacheMisses++;
        return null;
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _persistentCacheHits++;
      final metadata = NaiImageMetadata.fromJson(
        json,
      ).upgradeFromRawJsonIfNeeded();
      _memoryCache.put(hash, _MemoryEntry(metadata, raw!.length));
      return metadata;
    } catch (e) {
      _persistentCacheMisses++;
      return null;
    }
  }

  /// 依次查 L1、L2，L2 命中会放入 L1
  Future<NaiImageMetadata?> lookup(String hash) async =>
      getFromMemory(hash) ?? await getFromPersistent(hash);

  /// 保存到两级缓存
  Future<void> save(String hash, NaiImageMetadata metadata) async {
    final raw = MetadataCacheEntryCodec.encode(
      jsonEncode(metadata.toJson()),
      writtenAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    // L1 内存缓存
    _memoryCache.put(hash, _MemoryEntry(metadata, raw.length));

    // L2 持久化缓存
    try {
      await _getBox().put(hash, raw);
    } catch (e) {
      AppLogger.w(
        'Failed to save to persistent cache: $e',
        'MetadataCacheManager',
      );
    }
  }

  /// 只清 L1；L2 由容量淘汰管理，内存压力下不丢持久化结果
  void clearMemory() => _memoryCache.clear();

  // ==================== 统计信息 ====================

  /// 内存缓存命中率 (0.0 - 1.0)
  double get memoryHitRate {
    final total = _memoryCacheHits + _memoryCacheMisses;
    return total > 0 ? _memoryCacheHits / total : 0.0;
  }

  /// 持久化缓存命中率 (0.0 - 1.0)
  double get persistentHitRate {
    final total = _persistentCacheHits + _persistentCacheMisses;
    return total > 0 ? _persistentCacheHits / total : 0.0;
  }

  /// 内存缓存大小
  int get memorySize => _memoryCache.length;

  /// 内存缓存估算字节数：按各条目序列化后的字符数计 UTF-16 宽度
  int get estimatedMemoryBytes {
    var codeUnits = 0;
    for (final entry in _memoryCache.entries) {
      codeUnits += entry.value.serializedLength;
    }
    return codeUnits * 2;
  }

  /// 持久化缓存大小
  int get persistentSize {
    final box = _persistentBox;
    if (box == null || !box.isOpen) return 0;
    return box.length - (box.containsKey(_versionKey) ? 1 : 0);
  }

  /// Hive Box 实例（供外部访问，如 L2CacheCleaner）
  LazyBox<String>? get box => _persistentBox;

  /// 重置统计
  void resetStatistics() {
    _memoryCacheHits = 0;
    _memoryCacheMisses = 0;
    _persistentCacheHits = 0;
    _persistentCacheMisses = 0;
  }

  /// 获取详细统计
  Map<String, dynamic> getStatistics() => {
    'memorySize': memorySize,
    'memoryHitRate': memoryHitRate,
    'persistentSize': persistentSize,
    'persistentHitRate': persistentHitRate,
    'memoryHits': _memoryCacheHits,
    'memoryMisses': _memoryCacheMisses,
    'persistentHits': _persistentCacheHits,
    'persistentMisses': _persistentCacheMisses,
  };

  // ==================== 私有方法 ====================

  LazyBox<String> _getBox() {
    if (_persistentBox == null || !_persistentBox!.isOpen) {
      throw StateError(
        'MetadataCacheManager not initialized. Call initialize() first.',
      );
    }
    return _persistentBox!;
  }

  Future<void> _migrateCacheIfNeeded() async {
    final box = _persistentBox!;
    try {
      final storedVersion =
          int.tryParse(await box.get(_versionKey) ?? '1') ?? 1;

      if (storedVersion < _currentCacheVersion) {
        AppLogger.i(
          'Cache migration needed: v$storedVersion -> v$_currentCacheVersion',
          'MetadataCacheManager',
        );
        await _discardAll(box);
        await box.put(_versionKey, _currentCacheVersion.toString());
        AppLogger.i(
          'Cache migrated to version $_currentCacheVersion',
          'MetadataCacheManager',
        );
      }
    } catch (e) {
      AppLogger.w(
        'Cache version check failed, clearing cache',
        'MetadataCacheManager',
      );
      await _discardAll(box);
    }
  }

  /// 版本升级时旧解析快照整体作废
  Future<void> _discardAll(LazyBox<String> box) async {
    _memoryCache.clear();
    try {
      await box.clear();
    } catch (e, stack) {
      AppLogger.e(
        'Failed to clear persistent cache',
        e,
        stack,
        'MetadataCacheManager',
      );
    }
  }
}

final class _MemoryEntry {
  const _MemoryEntry(this.metadata, this.serializedLength);

  final NaiImageMetadata metadata;

  /// 序列化后的字符数，内存估算不必再编码一次
  final int serializedLength;
}

/// LRU 内存缓存
class _LRUCache<K, V> {
  final int capacity;
  final _map = <K, V>{};

  _LRUCache({required this.capacity});

  int get length => _map.length;

  Iterable<MapEntry<K, V>> get entries => _map.entries;

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    while (_map.length >= capacity) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  bool containsKey(K key) => _map.containsKey(key);

  void clear() => _map.clear();
}
