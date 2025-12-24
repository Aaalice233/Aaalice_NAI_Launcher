import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/tag/tag_suggestion.dart';
import '../utils/app_logger.dart';

part 'tag_cache_service.g.dart';

/// 缓存条目
class CacheEntry {
  final List<TagSuggestion> tags;
  final DateTime createdAt;
  int accessCount;
  DateTime lastAccessedAt;

  CacheEntry({
    required this.tags,
    required this.createdAt,
    this.accessCount = 1,
    DateTime? lastAccessedAt,
  }) : lastAccessedAt = lastAccessedAt ?? createdAt;

  /// 检查是否过期
  bool isExpired(Duration ttl) {
    return DateTime.now().difference(createdAt) > ttl;
  }

  /// 记录访问
  void recordAccess() {
    accessCount++;
    lastAccessedAt = DateTime.now();
  }

  /// 转换为 JSON（用于持久化）
  Map<String, dynamic> toJson() => {
        'tags': tags.map((t) => t.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'accessCount': accessCount,
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
      };

  /// 从 JSON 创建
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      tags: (json['tags'] as List)
          .map((t) => TagSuggestion.fromJson(t as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      accessCount: json['accessCount'] as int? ?? 1,
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.parse(json['lastAccessedAt'] as String)
          : null,
    );
  }
}

/// 三层缓存服务
///
/// L1: 内存缓存 - 最快访问
/// L2: Hive 本地存储 - 跨会话保留
/// L3: API 请求 - 最终数据源（在 Provider 中处理）
///
/// 特性：
/// - LFU (Least Frequently Used) 淘汰策略
/// - TTL (Time To Live) 过期机制
/// - 自动持久化到本地存储
class TagCacheService {
  /// L1: 内存缓存
  final Map<String, CacheEntry> _memoryCache = {};

  /// L2: Hive Box（懒加载）
  Box? _cacheBox;

  /// 缓存配置
  static const int maxMemoryCacheSize = 500;
  static const int maxStorageCacheSize = 2000;
  static const Duration cacheTTL = Duration(hours: 2);

  /// Hive Box 名称
  static const String boxName = 'tag_cache';
  static const String cacheDataKey = 'tag_cache_data';

  /// 初始化（加载本地缓存到内存）
  Future<void> init() async {
    try {
      _cacheBox = await Hive.openBox(boxName);
      await _loadFromStorage();
      AppLogger.d(
        'TagCacheService initialized, memory cache size: ${_memoryCache.length}',
        'Cache',
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to initialize TagCacheService: $e',
        e,
        stack,
        'Cache',
      );
    }
  }

  /// 从 L2 存储加载到 L1 内存
  Future<void> _loadFromStorage() async {
    if (_cacheBox == null) return;

    try {
      final data = _cacheBox!.get(cacheDataKey);
      if (data != null) {
        final Map<String, dynamic> cacheData = Map<String, dynamic>.from(
          jsonDecode(data as String) as Map,
        );

        int loadedCount = 0;
        int expiredCount = 0;

        for (final entry in cacheData.entries) {
          try {
            final cacheEntry = CacheEntry.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            );

            // 跳过过期的条目
            if (cacheEntry.isExpired(cacheTTL)) {
              expiredCount++;
              continue;
            }

            _memoryCache[entry.key] = cacheEntry;
            loadedCount++;

            // 限制内存缓存大小
            if (_memoryCache.length >= maxMemoryCacheSize) {
              break;
            }
          } catch (e) {
            AppLogger.w('Failed to parse cache entry: ${entry.key}', 'Cache');
          }
        }

        AppLogger.d(
          'Loaded $loadedCount entries from storage, skipped $expiredCount expired',
          'Cache',
        );
      }
    } catch (e, stack) {
      AppLogger.e('Failed to load cache from storage: $e', e, stack, 'Cache');
    }
  }

  /// 从缓存获取
  ///
  /// 先查 L1 内存，未命中则查 L2 存储
  /// 返回 null 表示未命中
  List<TagSuggestion>? get(String query) {
    final key = _normalizeKey(query);

    // L1: 内存缓存
    final entry = _memoryCache[key];
    if (entry != null) {
      // 检查是否过期
      if (entry.isExpired(cacheTTL)) {
        _memoryCache.remove(key);
        AppLogger.d('Cache expired for: $key', 'Cache');
        return null;
      }

      // 记录访问（用于 LFU）
      entry.recordAccess();
      AppLogger.d('Cache HIT (L1): $key', 'Cache');
      return entry.tags;
    }

    AppLogger.d('Cache MISS: $key', 'Cache');
    return null;
  }

  /// 设置缓存
  ///
  /// 同时写入 L1 内存和 L2 存储
  Future<void> set(String query, List<TagSuggestion> tags) async {
    final key = _normalizeKey(query);

    // 检查是否需要淘汰
    if (_memoryCache.length >= maxMemoryCacheSize) {
      _evictLFU();
    }

    // 写入 L1 内存
    _memoryCache[key] = CacheEntry(
      tags: tags,
      createdAt: DateTime.now(),
    );

    AppLogger.d('Cache SET: $key (${tags.length} tags)', 'Cache');

    // 异步持久化到 L2 存储
    _persistToStorage();
  }

  /// LFU 淘汰策略
  ///
  /// 淘汰访问频率最低的条目
  void _evictLFU() {
    if (_memoryCache.isEmpty) return;

    // 找出访问频率最低的条目
    String? leastUsedKey;
    int minAccessCount = double.maxFinite.toInt();
    DateTime? oldestAccess;

    for (final entry in _memoryCache.entries) {
      final cacheEntry = entry.value;

      // 优先淘汰已过期的
      if (cacheEntry.isExpired(cacheTTL)) {
        leastUsedKey = entry.key;
        break;
      }

      // 比较访问频率
      if (cacheEntry.accessCount < minAccessCount ||
          (cacheEntry.accessCount == minAccessCount &&
              (oldestAccess == null ||
                  cacheEntry.lastAccessedAt.isBefore(oldestAccess)))) {
        minAccessCount = cacheEntry.accessCount;
        oldestAccess = cacheEntry.lastAccessedAt;
        leastUsedKey = entry.key;
      }
    }

    if (leastUsedKey != null) {
      _memoryCache.remove(leastUsedKey);
      AppLogger.d('Cache evicted (LFU): $leastUsedKey', 'Cache');
    }
  }

  /// 持久化到 L2 存储
  Future<void> _persistToStorage() async {
    if (_cacheBox == null) return;

    try {
      // 将内存缓存序列化
      final Map<String, dynamic> cacheData = {};
      for (final entry in _memoryCache.entries) {
        cacheData[entry.key] = entry.value.toJson();
      }

      // 写入 Hive
      await _cacheBox!.put(cacheDataKey, jsonEncode(cacheData));
      AppLogger.d('Cache persisted: ${_memoryCache.length} entries', 'Cache');
    } catch (e, stack) {
      AppLogger.e('Failed to persist cache: $e', e, stack, 'Cache');
    }
  }

  /// 清除所有缓存
  Future<void> clear() async {
    _memoryCache.clear();
    if (_cacheBox != null) {
      await _cacheBox!.clear();
    }
    AppLogger.d('Cache cleared', 'Cache');
  }

  /// 获取缓存统计
  Map<String, dynamic> getStats() {
    int totalAccessCount = 0;
    int expiredCount = 0;

    for (final entry in _memoryCache.values) {
      totalAccessCount += entry.accessCount;
      if (entry.isExpired(cacheTTL)) {
        expiredCount++;
      }
    }

    return {
      'memoryCacheSize': _memoryCache.length,
      'maxMemoryCacheSize': maxMemoryCacheSize,
      'totalAccessCount': totalAccessCount,
      'expiredCount': expiredCount,
    };
  }

  /// 标准化缓存键
  String _normalizeKey(String query) {
    return query.trim().toLowerCase();
  }
}

/// TagCacheService Provider
@riverpod
TagCacheService tagCacheService(Ref ref) {
  final service = TagCacheService();
  // 初始化在 LocalStorageService 中进行
  return service;
}
