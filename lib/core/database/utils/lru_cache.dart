import 'dart:collection';

/// 通用 LRU 缓存实现
///
/// 使用 LinkedHashMap 实现 LRU 缓存，限制最大条目数。
/// 当缓存满时，自动移除最久未使用的条目。
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  LRUCache({required this.maxSize});

  /// 获取缓存值
  ///
  /// 如果找到，将条目移到末尾（标记为最近使用）
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
      _hitCount++;
      return value;
    }
    _missCount++;
    return null;
  }

  /// 设置缓存值
  ///
  /// 如果缓存已满，先移除最旧的条目
  void put(K key, V value) {
    _cache.remove(key);

    if (_cache.length >= maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
      _evictionCount++;
    }

    _cache[key] = value;
  }

  /// 检查是否包含键
  bool containsKey(K key) => _cache.containsKey(key);

  /// 获取当前大小
  int get size => _cache.length;

  /// 检查是否为空
  bool get isEmpty => _cache.isEmpty;

  /// 检查是否已满
  bool get isFull => _cache.length >= maxSize;

  /// 清除所有缓存
  void clear() {
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
  }

  /// 移除特定键
  bool remove(K key) => _cache.remove(key) != null;

  /// 获取命中率
  double get hitRate {
    final total = _hitCount + _missCount;
    return total == 0 ? 0.0 : _hitCount / total;
  }

  /// 获取统计信息
  Map<String, dynamic> get statistics => {
        'size': _cache.length,
        'maxSize': maxSize,
        'hitCount': _hitCount,
        'missCount': _missCount,
        'evictionCount': _evictionCount,
        'hitRate': hitRate,
      };
}
