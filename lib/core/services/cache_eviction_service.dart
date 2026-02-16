import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_logger.dart';

part 'cache_eviction_service.g.dart';

/// 可淘汰缓存条目接口
///
/// 实现此接口的条目可以被 CacheEvictionService 管理
abstract class EvictableEntry {
  /// 条目大小（字节）
  int get sizeInBytes;

  /// 条目创建时间
  DateTime get createdAt;

  /// 最后访问时间
  DateTime get lastAccessedAt;

  /// 访问次数
  int get accessCount;

  /// 条目键
  String get key;
}

/// 缓存淘汰策略
enum EvictionStrategy {
  /// 大小优先：淘汰占用空间最大的条目
  sizeFirst,

  /// 数量优先：淘汰访问次数最少的条目
  countFirst,

  /// 年龄优先：淘汰最久未访问的条目
  ageFirst,
}

/// 缓存淘汰服务
///
/// 实现多级淘汰策略：
/// 1. 大小优先：首先淘汰占用空间最大的条目，快速释放内存
/// 2. 数量优先：如果大小相同，淘汰访问次数最少的条目（LFU）
/// 3. 年龄优先：如果访问次数也相同，淘汰最久未访问的条目（LRU）
///
/// 适用于需要精细控制内存使用的场景，如图片缓存、大数据对象缓存等。
class CacheEvictionService {
  /// 最大缓存大小（字节）
  final int maxSizeInBytes;

  /// 最大条目数
  final int maxEntries;

  /// 内部存储
  final LinkedHashMap<String, EvictableEntry> _cache = LinkedHashMap();

  /// 当前总大小（字节）
  int _currentSizeInBytes = 0;

  /// 统计信息
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;
  int _sizeEvictionCount = 0;
  int _countEvictionCount = 0;
  int _ageEvictionCount = 0;

  /// 构造函数
  CacheEvictionService({
    this.maxSizeInBytes = 200 * 1024 * 1024, // 默认 200MB
    this.maxEntries = 1000,
  });

  /// 添加条目到缓存
  ///
  /// 如果缓存已满，会根据多级淘汰策略自动移除条目
  void put(EvictableEntry entry) {
    // 如果已存在，先移除旧的
    if (_cache.containsKey(entry.key)) {
      _removeEntry(entry.key);
    }

    // 检查是否需要淘汰
    while (_shouldEvict(entry.sizeInBytes)) {
      _evict();
    }

    // 添加新条目
    _cache[entry.key] = entry;
    _currentSizeInBytes += entry.sizeInBytes;

    AppLogger.d(
      'Cache entry added: ${entry.key} (${_formatBytes(entry.sizeInBytes)})',
      'CacheEvictionService',
    );
  }

  /// 获取缓存条目
  ///
  /// 返回条目并更新访问统计（但不修改最后访问时间，由调用方控制）
  EvictableEntry? get(String key) {
    final entry = _cache[key];
    if (entry != null) {
      _hitCount++;
      AppLogger.d(
        'Cache hit: $key (hits: $_hitCount, misses: $_missCount)',
        'CacheEvictionService',
      );
      return entry;
    } else {
      _missCount++;
      AppLogger.d(
        'Cache miss: $key (hits: $_hitCount, misses: $_missCount)',
        'CacheEvictionService',
      );
      return null;
    }
  }

  /// 移除指定条目
  bool remove(String key) {
    final removed = _removeEntry(key);
    if (removed) {
      AppLogger.d(
        'Cache entry removed: $key (current size: ${_formatBytes(_currentSizeInBytes)})',
        'CacheEvictionService',
      );
    }
    return removed;
  }

  /// 检查是否应该淘汰条目
  bool _shouldEvict(int newEntrySize) {
    // 如果添加新条目会超出大小限制
    if (_currentSizeInBytes + newEntrySize > maxSizeInBytes) {
      return true;
    }
    // 如果添加新条目会超出数量限制
    if (_cache.length >= maxEntries) {
      return true;
    }
    return false;
  }

  /// 执行淘汰（多级策略）
  ///
  /// 1. 大小优先：找出占用空间最大的条目
  /// 2. 数量优先：如果大小相同，找出访问次数最少的
  /// 3. 年龄优先：如果访问次数也相同，找出最久未访问的
  void _evict() {
    if (_cache.isEmpty) return;

    String? keyToEvict;
    EvictableEntry? entryToEvict;

    for (final entry in _cache.entries) {
      final currentEntry = entry.value;

      if (keyToEvict == null || entryToEvict == null) {
        keyToEvict = entry.key;
        entryToEvict = currentEntry;
        continue;
      }

      // 多级比较策略
      final comparison = _compareEntries(currentEntry, entryToEvict);
      if (comparison > 0) {
        // currentEntry 更应该被淘汰
        keyToEvict = entry.key;
        entryToEvict = currentEntry;
      }
    }

    if (keyToEvict != null) {
      _removeEntry(keyToEvict);
      _evictionCount++;

      // 记录淘汰原因
      if (entryToEvict != null) {
        final size = entryToEvict.sizeInBytes;
        final count = entryToEvict.accessCount;
        final age = DateTime.now().difference(entryToEvict.lastAccessedAt);

        AppLogger.d(
          'Evicted by size priority: $keyToEvict (${_formatBytes(size)}, '
              'access: $count, age: ${age.inMinutes}m)',
          'CacheEvictionService',
        );
      }
    }
  }

  /// 比较两个条目，返回正值表示 entry1 更应该被淘汰
  ///
  /// 多级策略：大小 → 访问次数 → 年龄
  int _compareEntries(EvictableEntry entry1, EvictableEntry entry2) {
    // 第一级：大小优先（越大越优先淘汰）
    if (entry1.sizeInBytes != entry2.sizeInBytes) {
      return entry1.sizeInBytes.compareTo(entry2.sizeInBytes);
    }

    // 第二级：数量优先（访问次数越少越优先淘汰）
    if (entry1.accessCount != entry2.accessCount) {
      return entry2.accessCount.compareTo(entry1.accessCount);
    }

    // 第三级：年龄优先（越久未访问越优先淘汰）
    return entry2.lastAccessedAt.compareTo(entry1.lastAccessedAt);
  }

  /// 内部移除条目方法
  bool _removeEntry(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _currentSizeInBytes -= entry.sizeInBytes;
      if (_currentSizeInBytes < 0) {
        _currentSizeInBytes = 0;
      }
      return true;
    }
    return false;
  }

  /// 根据策略淘汰指定数量的条目
  ///
  /// 用于手动触发特定策略的淘汰
  int evictByStrategy(EvictionStrategy strategy, int count) {
    int evicted = 0;

    while (evicted < count && _cache.isNotEmpty) {
      String? keyToEvict;
      EvictableEntry? entryToEvict;

      for (final entry in _cache.entries) {
        final currentEntry = entry.value;

        if (keyToEvict == null || entryToEvict == null) {
          keyToEvict = entry.key;
          entryToEvict = currentEntry;
          continue;
        }

        bool shouldEvictCurrent = false;
        switch (strategy) {
          case EvictionStrategy.sizeFirst:
            shouldEvictCurrent =
                currentEntry.sizeInBytes > entryToEvict.sizeInBytes;
          case EvictionStrategy.countFirst:
            shouldEvictCurrent =
                currentEntry.accessCount < entryToEvict.accessCount;
          case EvictionStrategy.ageFirst:
            shouldEvictCurrent = currentEntry.lastAccessedAt
                .isBefore(entryToEvict.lastAccessedAt);
        }

        if (shouldEvictCurrent) {
          keyToEvict = entry.key;
          entryToEvict = currentEntry;
        }
      }

      if (keyToEvict != null) {
        _removeEntry(keyToEvict);
        evicted++;
        _evictionCount++;

        switch (strategy) {
          case EvictionStrategy.sizeFirst:
            _sizeEvictionCount++;
          case EvictionStrategy.countFirst:
            _countEvictionCount++;
          case EvictionStrategy.ageFirst:
            _ageEvictionCount++;
        }

        AppLogger.d(
          'Evicted by $strategy: $keyToEvict',
          'CacheEvictionService',
        );
      } else {
        break;
      }
    }

    return evicted;
  }

  /// 清除所有缓存
  void clear() {
    final previousSize = _cache.length;
    final previousBytes = _currentSizeInBytes;
    _cache.clear();
    _currentSizeInBytes = 0;

    AppLogger.i(
      'Cache cleared: removed $previousSize entries, '
          'freed ${_formatBytes(previousBytes)}',
      'CacheEvictionService',
    );
  }

  /// 获取缓存统计信息
  Map<String, dynamic> get statistics => {
        'entryCount': _cache.length,
        'maxEntries': maxEntries,
        'currentSizeInBytes': _currentSizeInBytes,
        'maxSizeInBytes': maxSizeInBytes,
        'currentSizeFormatted': _formatBytes(_currentSizeInBytes),
        'maxSizeFormatted': _formatBytes(maxSizeInBytes),
        'utilizationRate': _cache.length / maxEntries,
        'sizeUtilizationRate': _currentSizeInBytes / maxSizeInBytes,
        'hitCount': _hitCount,
        'missCount': _missCount,
        'hitRate': hitRate,
        'totalEvictions': _evictionCount,
        'sizeEvictions': _sizeEvictionCount,
        'countEvictions': _countEvictionCount,
        'ageEvictions': _ageEvictionCount,
      };

  /// 获取命中率
  double get hitRate {
    final total = _hitCount + _missCount;
    return total == 0 ? 0.0 : _hitCount / total;
  }

  /// 当前缓存大小（字节）
  int get currentSizeInBytes => _currentSizeInBytes;

  /// 当前条目数
  int get entryCount => _cache.length;

  /// 是否为空
  bool get isEmpty => _cache.isEmpty;

  /// 是否已满
  bool get isFull =>
      _cache.length >= maxEntries || _currentSizeInBytes >= maxSizeInBytes;

  /// 获取所有缓存键
  Iterable<String> get keys => _cache.keys;

  /// 格式化字节大小为人类可读格式
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// CacheEvictionService Provider
@riverpod
CacheEvictionService cacheEvictionService(Ref ref) {
  return CacheEvictionService();
}
