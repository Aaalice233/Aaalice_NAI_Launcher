import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../../models/online_gallery/gallery_item.dart';
import '../../../models/online_gallery/gallery_source.dart';

class GalleryRandomScope {
  GalleryRandomScope({
    required this.sourceId,
    required this.feedKind,
    required Map<String, Object?> fields,
  }) : fields = Map.unmodifiable(fields);

  final GallerySourceId sourceId;
  final GalleryFeedKind feedKind;
  final Map<String, Object?> fields;

  String get stableKey {
    final entries = fields.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return GalleryRandomCacheKeys._hashComponents([
      sourceId.key,
      feedKind.name,
      for (final entry in entries) '${entry.key}:${entry.value}',
    ]);
  }
}

class GalleryRandomSampler {
  GalleryRandomSampler({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  List<T> shuffle<T>(Iterable<T> values) {
    final result = values.toList(growable: false);
    for (var index = result.length - 1; index > 0; index--) {
      final swapIndex = _random.nextInt(index + 1);
      final value = result[index];
      result[index] = result[swapIndex];
      result[swapIndex] = value;
    }
    return result;
  }

  /// Returns a deterministic slice of a keyed pseudo-random permutation.
  ///
  /// The Feistel permutation preserves full coverage without copying [values].
  /// Cycle walking restricts its power-of-two domain to the exact list length,
  /// so consecutive slices read only the requested entries and never repeat.
  List<T> permutationSlice<T>(
    List<T> values, {
    required int seed,
    required int offset,
    required int count,
  }) {
    if (values.isEmpty || offset >= values.length || count <= 0) {
      return const [];
    }
    final end = min(offset + count, values.length);
    return [
      for (var position = offset; position < end; position++)
        values[_permutedIndex(position, values.length, seed)],
    ];
  }

  int _permutedIndex(int position, int length, int seed) {
    if (length == 1) return 0;
    var halfBits = 1;
    while ((1 << (halfBits * 2)) < length) {
      halfBits++;
    }
    final halfMask = (1 << halfBits) - 1;
    var value = position;
    do {
      var left = value >> halfBits;
      var right = value & halfMask;
      for (var round = 0; round < 6; round++) {
        final nextLeft = right;
        final nextRight = left ^ _roundFunction(right, seed, round, halfMask);
        left = nextLeft;
        right = nextRight;
      }
      value = (left << halfBits) | right;
    } while (value >= length);
    return value;
  }

  int _roundFunction(int value, int seed, int round, int mask) {
    var mixed = (value ^ seed ^ (round * 0x9e3779b9)) & 0xffffffff;
    mixed = ((mixed ^ (mixed >>> 16)) * 0x45d9f3b) & 0xffffffff;
    mixed = ((mixed ^ (mixed >>> 16)) * 0x45d9f3b) & 0xffffffff;
    return (mixed ^ (mixed >>> 16)) & mask;
  }
}

/// LRU cache entry for gallery random sampling
class _CacheEntry<T> {
  _CacheEntry(this.value, this.timestamp);

  final T value;
  final DateTime timestamp;
}

/// LRU cache with TTL for gallery random sampling strategies
class GalleryRandomCache<T> {
  GalleryRandomCache({required this.maxSize, required this.ttl});

  final int maxSize;
  final Duration ttl;
  final Map<String, _CacheEntry<T>> _cache = {};
  final List<String> _accessOrder = [];

  T? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    final now = DateTime.now();
    if (now.difference(entry.timestamp) > ttl) {
      _cache.remove(key);
      _accessOrder.remove(key);
      return null;
    }

    // Update access order
    _accessOrder.remove(key);
    _accessOrder.add(key);
    return entry.value;
  }

  void put(String key, T value) {
    final now = DateTime.now();

    if (_cache.containsKey(key)) {
      _cache[key] = _CacheEntry(value, now);
      _accessOrder.remove(key);
      _accessOrder.add(key);
      return;
    }

    if (_cache.length >= maxSize) {
      final oldestKey = _accessOrder.removeAt(0);
      _cache.remove(oldestKey);
    }

    _cache[key] = _CacheEntry(value, now);
    _accessOrder.add(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }
}

/// Danbooru ID boundary probe result for random sampling
class DanbooruIdBoundary {
  const DanbooruIdBoundary({
    required this.minId,
    required this.maxId,
    required this.oldestPageSize,
    required this.newestPageSize,
    this.edgeItems = const [],
  });

  final int minId;
  final int maxId;
  final int oldestPageSize;
  final int newestPageSize;
  final List<GalleryItem> edgeItems;

  bool get isValid => maxId > minId && oldestPageSize > 0 && newestPageSize > 0;
}

/// AI TAG total count probe result for random page selection
class AiTagTotalInfo {
  const AiTagTotalInfo({
    required this.totalCount,
    required this.pageSize,
    this.probedPage,
  });

  final int totalCount;
  final int pageSize;
  final GalleryPage? probedPage;

  int get totalPages => (totalCount / pageSize).ceil();
  bool get isValid => totalCount > 0 && pageSize > 0;
}

/// Danbooru ranking window state for continuous 4-page shuffling
class DanbooruRankingWindow {
  DanbooruRankingWindow({required this.windowSize, required this.pageSize});

  final int windowSize; // Always 4
  final int pageSize;
  final Set<int> _visitedPages = {};
  final List<int> _availablePages = [];

  void initialize(int totalAvailablePages) {
    _visitedPages.clear();
    _availablePages.clear();
    for (var i = 1; i <= totalAvailablePages; i++) {
      _availablePages.add(i);
    }
  }

  List<int> getNextWindow(Random random) {
    if (_availablePages.length < windowSize) {
      // Reset if insufficient pages remaining
      initialize(_availablePages.length + _visitedPages.length);
    }

    // Select 4 consecutive unvisited pages
    final startIndex = random.nextInt(
      (_availablePages.length - windowSize + 1).clamp(
        1,
        _availablePages.length,
      ),
    );
    final window = _availablePages.sublist(startIndex, startIndex + windowSize);

    // Mark as visited and remove from available
    for (final page in window) {
      _visitedPages.add(page);
      _availablePages.remove(page);
    }

    return List<int>.from(window);
  }

  String encodeNextCursor(List<int> unvisitedPages) {
    final encoded = base64Encode(utf8.encode(unvisitedPages.join(',')));
    return 'rw:$encoded';
  }

  List<int>? decodeNextCursor(String? cursor) {
    if (cursor == null || !cursor.startsWith('rw:')) return null;

    try {
      final encoded = cursor.substring(3);
      final decoded = utf8.decode(base64Decode(encoded));
      return decoded.split(',').map(int.parse).toList();
    } catch (_) {
      return null;
    }
  }
}

/// Utility functions for generating cache keys
class GalleryRandomCacheKeys {
  /// Generate cache key for Danbooru ID boundary probe
  static String danbooruBoundary({
    required String query,
    required Set<String> ratings,
    required DateTime? dateStart,
    required DateTime? dateEnd,
    required String? userHash, // Desensitized account identity
  }) {
    final components = [
      'danbooru_boundary',
      _normalizeQuery(query),
      ratings.toList()..sort(),
      dateStart?.millisecondsSinceEpoch ?? '',
      dateEnd?.millisecondsSinceEpoch ?? '',
      userHash ?? 'anonymous',
    ];
    return _hashComponents(components);
  }

  /// Generate cache key for AI TAG total count probe
  static String aiTagTotal({
    required String query,
    required String prompt,
    required String timeRange,
  }) {
    final components = [
      'aitag_total',
      _normalizeQuery(query),
      _normalizeQuery(prompt),
      timeRange,
    ];
    return _hashComponents(components);
  }

  /// Generate cache key for AI TAG ranking total
  static String aiTagRankingTotal({
    required String period,
    required String query,
    required String prompt,
  }) {
    final components = [
      'aitag_ranking',
      period,
      _normalizeQuery(query),
      _normalizeQuery(prompt),
    ];
    return _hashComponents(components);
  }

  static String _normalizeQuery(String query) {
    return query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _hashComponents(List<Object> components) {
    final content = components.map((c) => c.toString()).join('|');
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // First 16 chars
  }
}
