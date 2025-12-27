import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/prompt/pool_post.dart';

part 'pool_cache_service.g.dart';

/// 缓存格式版本号
///
/// 当数据结构发生变化时递增此版本号
const int _cacheFormatVersion = 2;

/// Pool 缓存条目
///
/// 存储 Pool 的所有帖子及其分类标签
class PoolCacheEntry {
  final int poolId;
  final String poolName;
  final List<PoolPost> posts;
  final int totalPostCount;
  final DateTime lastSyncedAt;

  PoolCacheEntry({
    required this.poolId,
    required this.poolName,
    required this.posts,
    required this.totalPostCount,
    required this.lastSyncedAt,
  });

  /// 已缓存的帖子数量
  int get cachedPostCount => posts.length;

  /// 是否已完全同步
  bool get isFullySynced => cachedPostCount >= totalPostCount;

  Map<String, dynamic> toJson() => {
        'poolId': poolId,
        'poolName': poolName,
        'posts': posts.map((p) => p.toJson()).toList(),
        'totalPostCount': totalPostCount,
        'lastSyncedAt': lastSyncedAt.toIso8601String(),
        'version': _cacheFormatVersion,
      };

  factory PoolCacheEntry.fromJson(Map<String, dynamic> json) {
    // 检查版本，如果是旧版本（没有 version 或 version < 当前版本），返回空 posts
    final version = json['version'] as int? ?? 1;
    if (version < _cacheFormatVersion) {
      // 旧格式：含有 tags 字段，需要重新同步
      return PoolCacheEntry(
        poolId: json['poolId'] as int,
        poolName: json['poolName'] as String,
        posts: [], // 空列表，触发重新同步
        totalPostCount: json['postCount'] as int? ?? 0,
        lastSyncedAt: DateTime.parse(json['lastSyncedAt'] as String),
      );
    }

    return PoolCacheEntry(
      poolId: json['poolId'] as int,
      poolName: json['poolName'] as String,
      posts: (json['posts'] as List)
          .map((p) => PoolPost.fromJson(p as Map<String, dynamic>))
          .toList(),
      totalPostCount: json['totalPostCount'] as int,
      lastSyncedAt: DateTime.parse(json['lastSyncedAt'] as String),
    );
  }
}

/// Pool 持久化缓存服务
///
/// 使用 Hive 存储 Pool 的所有帖子数据
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

  /// 保存 Pool 帖子到持久化缓存
  Future<void> savePoolPosts(
    int poolId,
    String poolName,
    List<PoolPost> posts,
    int totalPostCount,
  ) async {
    await _ensureInit();
    try {
      final entry = PoolCacheEntry(
        poolId: poolId,
        poolName: poolName,
        posts: posts,
        totalPostCount: totalPostCount,
        lastSyncedAt: DateTime.now(),
      );

      final key = _cacheKey(poolId);
      await _box?.put(key, jsonEncode(entry.toJson()));

      // 同时更新内存缓存
      _memoryCache[poolId] = entry;

      AppLogger.d(
        'Saved Pool to cache: $poolName (${posts.length} posts)',
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

  /// 获取随机帖子
  PoolPost? getRandomPost(int poolId, Random random) {
    final entry = _memoryCache[poolId];
    if (entry == null || entry.posts.isEmpty) return null;
    return entry.posts[random.nextInt(entry.posts.length)];
  }

  /// 获取多个随机帖子（不重复）
  List<PoolPost> getRandomPosts(int poolId, int count, Random random) {
    if (count <= 0) return [];

    final entry = _memoryCache[poolId];
    if (entry == null || entry.posts.isEmpty) return [];

    // 如果请求数量大于可用数量，返回全部（打乱顺序）
    if (count >= entry.posts.length) {
      final shuffled = List<PoolPost>.from(entry.posts);
      shuffled.shuffle(random);
      return shuffled;
    }

    // 使用 Fisher-Yates 部分洗牌选择不重复的元素
    final posts = List<PoolPost>.from(entry.posts);
    final result = <PoolPost>[];
    for (var i = 0; i < count; i++) {
      final j = random.nextInt(posts.length - i) + i;
      // 交换
      final temp = posts[i];
      posts[i] = posts[j];
      posts[j] = temp;
      result.add(posts[i]);
    }
    return result;
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

  /// 检查是否需要重新同步（旧格式或数据不完整）
  Future<bool> needsResync(int poolId) async {
    final entry = await getPool(poolId);
    if (entry == null) return true;
    // 如果 posts 为空（旧格式迁移），需要重新同步
    return entry.posts.isEmpty;
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
    var totalPosts = 0;
    for (final entry in pools.values) {
      totalPosts += entry.cachedPostCount;
    }

    return {
      'poolCount': pools.length,
      'totalPosts': totalPosts,
      'memoryCacheSize': _memoryCache.length,
    };
  }
}

/// Provider
@Riverpod(keepAlive: true)
PoolCacheService poolCacheService(Ref ref) {
  return PoolCacheService();
}
