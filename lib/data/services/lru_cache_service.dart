import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../models/gallery/local_image_record.dart';

part 'lru_cache_service.g.dart';

/// LRU (Least Recently Used) cache service for LocalImageRecord
///
/// 使用 LinkedHashMap 实现的 LRU 缓存，限制最大条目数为 1000
/// 当缓存满时，自动移除最久未使用的条目
///
/// Uses LinkedHashMap to implement LRU cache with a configurable max size (default 1000 entries).
/// When the cache is full, the least recently used entry is automatically evicted.
class LruCacheService {
  /// Maximum cache size (hard limit)
  final int maxSize;

  /// Internal storage using LinkedHashMap to maintain insertion order
  /// The first entry is the least recently used (LRU), the last is the most recently used
  final LinkedHashMap<String, LocalImageRecord> _cache = LinkedHashMap();

  /// Statistics counters for monitoring cache performance
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  /// Constructor with configurable max size (default 1000 for production use)
  LruCacheService({this.maxSize = 1000});

  /// Get cached record by file path
  ///
  /// Returns the cached record if found, and moves it to the end (mark as recently used).
  /// Returns null if not found.
  ///
  /// 通过文件路径获取缓存的记录。
  /// 如果找到，将记录移到末尾（标记为最近使用）。
  /// 如果未找到，返回 null。
  LocalImageRecord? get(String filePath) {
    final record = _cache.remove(filePath);
    if (record != null) {
      // Cache hit: move to end (most recently used)
      _cache[filePath] = record;
      _hitCount++;
      AppLogger.d(
        'LRU cache hit: $filePath (hit: $_hitCount, miss: $_missCount, evictions: $_evictionCount, size: ${_cache.length})',
        'LruCacheService',
      );
      return record;
    } else {
      // Cache miss
      _missCount++;
      AppLogger.d(
        'LRU cache miss: $filePath (hit: $_hitCount, miss: $_missCount, evictions: $_evictionCount, size: ${_cache.length})',
        'LruCacheService',
      );
      return null;
    }
  }

  /// Put a record into the cache
  ///
  /// If the key already exists, update it and move to the end.
  /// If the cache is full, evict the oldest entry (first in the map) before adding.
  ///
  /// 将记录放入缓存。
  /// 如果键已存在，更新并移到末尾。
  /// 如果缓存已满，在添加前淘汰最旧的条目（映射中的第一个）。
  void put(String filePath, LocalImageRecord record) {
    // Remove existing entry if present (will be re-added at the end)
    _cache.remove(filePath);

    // Evict oldest entry if cache is full
    if (_cache.length >= maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      _evictionCount++;
      AppLogger.d(
        'LRU cache evicted: $oldestKey (hit: $_hitCount, miss: $_missCount, evictions: $_evictionCount, size: ${_cache.length})',
        'LruCacheService',
      );
    }

    // Add new entry at the end (most recently used)
    _cache[filePath] = record;
  }

  /// Check if a file path is cached
  ///
  /// This does NOT update the LRU order (use get() if you need to access the record).
  ///
  /// 检查文件路径是否已缓存。
  /// 这不会更新 LRU 顺序（如果需要访问记录，请使用 get()）。
  bool contains(String filePath) {
    return _cache.containsKey(filePath);
  }

  /// Get current cache size
  ///
  /// 获取当前缓存大小
  int get size => _cache.length;

  /// Check if cache is empty
  ///
  /// 检查缓存是否为空
  bool get isEmpty => _cache.isEmpty;

  /// Check if cache is full
  ///
  /// 检查缓存是否已满
  bool get isFull => _cache.length >= maxSize;

  /// Clear all cached entries and reset statistics
  ///
  /// 清除所有缓存条目并重置统计信息
  void clear() {
    final previousSize = _cache.length;
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
    AppLogger.i(
      'LRU cache cleared: removed $previousSize entries',
      'LruCacheService',
    );
  }

  /// Remove a specific entry from the cache
  ///
  /// Returns true if the entry was removed, false if it didn't exist.
  ///
  /// 从缓存中移除特定条目。
  /// 如果条目被移除返回 true，如果不存在返回 false。
  bool remove(String filePath) {
    final removed = _cache.remove(filePath) != null;
    if (removed) {
      AppLogger.d(
        'LRU cache removed: $filePath (hit: $_hitCount, miss: $_missCount, evictions: $_evictionCount, size: ${_cache.length})',
        'LruCacheService',
      );
    }
    return removed;
  }

  /// Get cache hit rate (0.0 to 1.0)
  ///
  /// Returns 0 if no requests have been made.
  ///
  /// 获取缓存命中率（0.0 到 1.0）。
  /// 如果没有请求，返回 0。
  double get hitRate {
    final total = _hitCount + _missCount;
    return total == 0 ? 0.0 : _hitCount / total;
  }

  /// Get cache statistics
  ///
  /// 获取缓存统计信息
  Map<String, dynamic> get statistics => {
        'size': _cache.length,
        'maxSize': maxSize,
        'hitCount': _hitCount,
        'missCount': _missCount,
        'evictionCount': _evictionCount,
        'hitRate': hitRate,
      };
}

/// LruCacheService Provider
@Riverpod(keepAlive: true)
LruCacheService lruCacheService(Ref ref) {
  return LruCacheService();
}
