import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/nai_image_metadata.dart';

/// 元数据缓存管理器
///
/// 管理两层缓存：
/// - L1: 内存缓存 (LRU)
/// - L2: Hive 持久化缓存
class MetadataCacheManager {
  static final MetadataCacheManager _instance = MetadataCacheManager._internal();
  factory MetadataCacheManager() => _instance;
  MetadataCacheManager._internal();

  static const int _memoryCacheCapacity = 500;
  static const int _currentCacheVersion = 2;

  Box<String>? _persistentBox;
  final _memoryCache = _LRUCache<String, NaiImageMetadata>(capacity: _memoryCacheCapacity);

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
          ? Hive.box<String>(StorageKeys.localMetadataCacheBox)
          : await Hive.openBox<String>(StorageKeys.localMetadataCacheBox);

      await _migrateCacheIfNeeded();

      AppLogger.i(
        'MetadataCacheManager initialized: persistent cache has ${_persistentBox!.length} entries',
        'MetadataCacheManager',
      );
    } catch (e) {
      AppLogger.e('Failed to initialize MetadataCacheManager', e, null, 'MetadataCacheManager');
      rethrow;
    }
  }

  /// 从 L1 内存缓存获取
  NaiImageMetadata? getFromMemory(String hash) {
    final metadata = _memoryCache.get(hash);
    if (metadata != null) {
      _memoryCacheHits++;
      return metadata;
    }
    _memoryCacheMisses++;
    return null;
  }

  /// 从 L2 持久化缓存获取
  NaiImageMetadata? getFromPersistent(String hash) {
    try {
      final box = _getBox();
      final jsonString = box.get(hash);
      if (jsonString == null) {
        _persistentCacheMisses++;
        return null;
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _persistentCacheHits++;
      return NaiImageMetadata.fromJson(json);
    } catch (e) {
      _persistentCacheMisses++;
      return null;
    }
  }

  /// 保存到两级缓存
  Future<void> save(String hash, NaiImageMetadata metadata) async {
    // L1 内存缓存
    _memoryCache.put(hash, metadata);

    // L2 持久化缓存
    try {
      final box = _getBox();
      await box.put(hash, jsonEncode(metadata.toJson()));
    } catch (e) {
      AppLogger.w('Failed to save to persistent cache: $e', 'MetadataCacheManager');
    }
  }

  /// 清除所有缓存
  Future<void> clear() async {
    _memoryCache.clear();
    try {
      final box = _getBox();
      final version = box.get('_cacheVersion');
      await box.clear();
      if (version != null) {
        await box.put('_cacheVersion', version);
      }
    } catch (e, stack) {
      AppLogger.e('Failed to clear persistent cache', e, stack, 'MetadataCacheManager');
    }
  }

  /// 清除 L2 持久化缓存
  Future<void> clearPersistent() async {
    try {
      final box = _getBox();
      final version = box.get('_cacheVersion');
      await box.clear();
      if (version != null) {
        await box.put('_cacheVersion', version);
      }
    } catch (e, stack) {
      AppLogger.e('Failed to clear persistent cache', e, stack, 'MetadataCacheManager');
    }
  }

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

  /// 持久化缓存大小
  int get persistentSize {
    final box = _persistentBox;
    if (box == null || !box.isOpen) return 0;
    return box.length - (box.containsKey('_cacheVersion') ? 1 : 0);
  }

  /// Hive Box 实例（供外部访问，如 L2CacheCleaner）
  Box<String>? get box => _persistentBox;

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

  Box<String> _getBox() {
    if (_persistentBox == null || !_persistentBox!.isOpen) {
      throw StateError('MetadataCacheManager not initialized. Call initialize() first.');
    }
    return _persistentBox!;
  }

  Future<void> _migrateCacheIfNeeded() async {
    try {
      final box = _persistentBox!;
      final storedVersion = int.tryParse(box.get('_cacheVersion') ?? '1') ?? 1;

      if (storedVersion < _currentCacheVersion) {
        AppLogger.i(
          'Cache migration needed: v$storedVersion -> v$_currentCacheVersion',
          'MetadataCacheManager',
        );
        await clear();
        await box.put('_cacheVersion', _currentCacheVersion.toString());
        AppLogger.i('Cache migrated to version $_currentCacheVersion', 'MetadataCacheManager');
      }
    } catch (e) {
      AppLogger.w('Cache version check failed, clearing cache', 'MetadataCacheManager');
      await clear();
    }
  }
}

/// LRU 内存缓存
class _LRUCache<K, V> {
  final int capacity;
  final _map = <K, V>{};

  _LRUCache({required this.capacity});

  int get length => _map.length;

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
