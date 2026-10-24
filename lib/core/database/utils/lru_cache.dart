import 'dart:collection';

/// 通用 LRU 缓存实现
///
/// 使用 LinkedHashMap 实现 LRU 缓存，限制最大条目数；
/// 提供 [weigher] 与 [maxWeight] 时同时限制条目权重总和。
/// 当缓存满时，自动移除最久未使用的条目。
class LRUCache<K, V> {
  final int maxSize;
  final int? maxWeight;
  final int Function(V value)? _weigher;
  final LinkedHashMap<K, _WeightedEntry<V>> _cache = LinkedHashMap();

  int _totalWeight = 0;
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  LRUCache({
    required this.maxSize,
    this.maxWeight,
    int Function(V value)? weigher,
  }) : assert(
         (maxWeight == null) == (weigher == null),
         'maxWeight and weigher must be provided together',
       ),
       _weigher = weigher;

  /// 获取缓存值
  ///
  /// 如果找到，将条目移到末尾（标记为最近使用）
  V? get(K key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _cache[key] = entry;
      _hitCount++;
      return entry.value;
    }
    _missCount++;
    return null;
  }

  /// 设置缓存值
  ///
  /// 先按最久未使用顺序淘汰到条目数与权重预算以内；
  /// 单个权重超过 [maxWeight] 的值不写入，同键旧值也一并移除。
  void put(K key, V value) {
    remove(key);

    final weight = _weigher?.call(value) ?? 0;
    final budget = maxWeight;
    if (budget != null && weight > budget) return;

    while (_cache.isNotEmpty &&
        (_cache.length >= maxSize ||
            (budget != null && _totalWeight + weight > budget))) {
      remove(_cache.keys.first);
      _evictionCount++;
    }

    _cache[key] = _WeightedEntry(value, weight);
    _totalWeight += weight;
  }

  /// 检查是否包含键
  bool containsKey(K key) => _cache.containsKey(key);

  /// 获取当前大小
  int get size => _cache.length;

  /// 当前条目权重总和；未提供 [weigher] 时恒为 0
  int get totalWeight => _totalWeight;

  /// 检查是否为空
  bool get isEmpty => _cache.isEmpty;

  /// 检查是否已满
  bool get isFull => _cache.length >= maxSize;

  /// 清除所有缓存
  void clear() {
    _cache.clear();
    _totalWeight = 0;
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
  }

  /// 移除特定键
  bool remove(K key) {
    final entry = _cache.remove(key);
    if (entry == null) return false;
    _totalWeight -= entry.weight;
    return true;
  }

  /// 移除所有满足 [test] 的条目，返回移除数量；不改变其余条目的使用顺序
  int removeWhere(bool Function(K key, V value) test) {
    final doomed = [
      for (final MapEntry(:key, value: entry) in _cache.entries)
        if (test(key, entry.value)) key,
    ];
    for (final key in doomed) {
      remove(key);
    }
    return doomed.length;
  }

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

// 权重在写入时固定：值可变，删除或淘汰时重新称重会让总权重漂移
final class _WeightedEntry<V> {
  const _WeightedEntry(this.value, this.weight);

  final V value;
  final int weight;
}
