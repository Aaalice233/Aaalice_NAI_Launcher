import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/prompt/weighted_tag.dart';

part 'pool_cache_service.g.dart';

/// Pool 缓存条目
class PoolCacheEntry {
  final int poolId;
  final String poolName;
  final List<WeightedTag> tags;
  final int postCount;
  final DateTime lastSyncedAt;

  PoolCacheEntry({
    required this.poolId,
    required this.poolName,
    required this.tags,
    required this.postCount,
    required this.lastSyncedAt,
  });

  int get tagCount => tags.length;

  Map<String, dynamic> toJson() => {
        'poolId': poolId,
        'poolName': poolName,
        'tags': tags.map((t) => t.toJson()).toList(),
        'postCount': postCount,
        'lastSyncedAt': lastSyncedAt.toIso8601String(),
      };

  factory PoolCacheEntry.fromJson(Map<String, dynamic> json) {
    return PoolCacheEntry(
      poolId: json['poolId'] as int,
      poolName: json['poolName'] as String,
      tags: (json['tags'] as List)
          .map((t) => WeightedTag.fromJson(t as Map<String, dynamic>))
          .toList(),
      postCount: json['postCount'] as int,
      lastSyncedAt: DateTime.parse(json['lastSyncedAt'] as String),
    );
  }
}

/// Pool 持久化缓存服务
///
/// 使用 Hive 存储 Pool 提取的标签数据
class PoolCacheService {
  static const String _boxName = 'pool_full_cache';

  Box? _box;
  Future<void>? _initFuture;
  bool _isInitialized = false;

  /// 内存缓存（避免频繁反序列化）
  final Map<int, PoolCacheEntry> _memoryCache = {};

  /// 初始化服务
  Future<void> init() async {
    if (_isInitialized) return;
    _box = await Hive.openBox(_boxName);
    _isInitialized = true;
    AppLogger.d('PoolCacheService initialized', 'PoolCache');
  }

  /// 确保已初始化（线程安全）
  Future<void> _ensureInit() async {
    if (_isInitialized && _box != null && _box!.isOpen) return;

    _initFuture ??= init();
    await _initFuture;
  }

  /// 检查服务是否已初始化
  bool get isInitialized => _isInitialized;

  /// 生成缓存 key
  String _cacheKey(int poolId) => 'pool_$poolId';

  /// 保存 Pool 到持久化缓存
  Future<void> savePool(
    int poolId,
    String poolName,
    List<WeightedTag> tags,
    int postCount,
  ) async {
    await _ensureInit();
    try {
      final entry = PoolCacheEntry(
        poolId: poolId,
        poolName: poolName,
        tags: tags,
        postCount: postCount,
        lastSyncedAt: DateTime.now(),
      );

      final key = _cacheKey(poolId);
      await _box?.put(key, jsonEncode(entry.toJson()));

      // 同时更新内存缓存
      _memoryCache[poolId] = entry;

      AppLogger.d(
        'Saved Pool to cache: $poolName (${tags.length} tags)',
        'PoolCache',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to save Pool: $poolName', e, stack, 'PoolCache');
      rethrow;
    }
  }

  /// 从持久化缓存读取 Pool
  Future<PoolCacheEntry?> getPool(int poolId) async {
    // 优先检查内存缓存
    if (_memoryCache.containsKey(poolId)) {
      return _memoryCache[poolId];
    }

    await _ensureInit();
    try {
      final key = _cacheKey(poolId);
      final json = _box?.get(key) as String?;
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final entry = PoolCacheEntry.fromJson(data);
        // 加载到内存缓存
        _memoryCache[poolId] = entry;
        return entry;
      }
    } catch (e) {
      AppLogger.e('Failed to load Pool: $poolId', e, null, 'PoolCache');
    }
    return null;
  }

  /// 获取所有已缓存的 Pool
  Future<Map<int, PoolCacheEntry>> getAllCachedPools() async {
    await _ensureInit();
    final result = <int, PoolCacheEntry>{};

    try {
      final keys =
          _box?.keys.where((k) => k.toString().startsWith('pool_')) ?? [];
      for (final key in keys) {
        final json = _box?.get(key) as String?;
        if (json != null) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final entry = PoolCacheEntry.fromJson(data);
          result[entry.poolId] = entry;
          _memoryCache[entry.poolId] = entry;
        }
      }
    } catch (e) {
      AppLogger.e('Failed to load all cached pools', e, null, 'PoolCache');
    }

    return result;
  }

  /// 检查缓存是否存在（同步方法）
  bool hasCached(int poolId) {
    if (_memoryCache.containsKey(poolId)) {
      return true;
    }
    if (!_isInitialized || _box == null || !_box!.isOpen) {
      return false;
    }
    final key = _cacheKey(poolId);
    return _box!.containsKey(key);
  }

  /// 检查缓存是否存在（异步方法，确保已初始化）
  Future<bool> hasCachedAsync(int poolId) async {
    if (_memoryCache.containsKey(poolId)) {
      return true;
    }
    await _ensureInit();
    final key = _cacheKey(poolId);
    return _box?.containsKey(key) ?? false;
  }

  /// 清除指定 Pool 的缓存
  Future<void> removePool(int poolId) async {
    await _ensureInit();
    final key = _cacheKey(poolId);
    await _box?.delete(key);
    _memoryCache.remove(poolId);
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    await _ensureInit();
    await _box?.clear();
    _memoryCache.clear();
    AppLogger.d('Pool cache cleared', 'PoolCache');
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    await _ensureInit();
    final pools = await getAllCachedPools();
    var totalTags = 0;
    for (final entry in pools.values) {
      totalTags += entry.tagCount;
    }

    return {
      'poolCount': pools.length,
      'totalTags': totalTags,
      'memoryCacheSize': _memoryCache.length,
    };
  }
}

/// Provider
@Riverpod(keepAlive: true)
PoolCacheService poolCacheService(Ref ref) {
  return PoolCacheService();
}
