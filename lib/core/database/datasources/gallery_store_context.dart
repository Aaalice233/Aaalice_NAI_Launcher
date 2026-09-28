import '../../utils/app_logger.dart';
import '../utils/lru_cache.dart';
import 'gallery_records.dart';

class GalleryStoreContext {
  static const int _maxImageCacheSize = 500;
  static const int _maxQueryCacheSize = 100;
  static const int _slowQueryThresholdMs = 500;
  static const int _maxSlowQueryLogs = 100;

  final LRUCache<int, GalleryImageRecord> _imageCache = LRUCache(
    maxSize: _maxImageCacheSize,
  );
  final LRUCache<GalleryQueryCacheKey, List<dynamic>> _queryCache = LRUCache(
    maxSize: _maxQueryCacheSize,
  );
  final Set<int> favoriteCache = <int>{};
  final List<SlowQueryLog> _slowQueryLogs = <SlowQueryLog>[];

  bool favoritesLoaded = false;
  int _dataRevision = 0;

  int get dataRevision => _dataRevision;
  int get imageCacheSize => _imageCache.size;
  int get queryCacheSize => _queryCache.size;
  double get imageCacheHitRate => _imageCache.hitRate;
  double get queryCacheHitRate => _queryCache.hitRate;
  int get slowQueryCount => _slowQueryLogs.length;

  GalleryImageRecord? getImage(int id) => _imageCache.get(id);
  void putImage(int id, GalleryImageRecord image) => _imageCache.put(id, image);
  void removeImage(int id) => _imageCache.remove(id);

  List<T>? getQuery<T>(GalleryQueryCacheKey key) {
    return _queryCache.get(key)?.cast<T>();
  }

  void putQuery<T>(GalleryQueryCacheKey key, List<T> value) {
    _queryCache.put(key, value);
  }

  void markDataChanged() {
    _dataRevision++;
    _queryCache.clear();
  }

  void clearQueryCache() {
    _queryCache.clear();
    AppLogger.d('Gallery query cache cleared', 'GalleryDS');
  }

  void clearCache() {
    _imageCache.clear();
    _queryCache.clear();
    favoriteCache.clear();
    favoritesLoaded = false;
    _slowQueryLogs.clear();
    AppLogger.i('Gallery cache cleared', 'GalleryDS');
  }

  Map<String, dynamic> get cacheStatistics => {
    'imageCache': _imageCache.statistics,
    'queryCache': _queryCache.statistics,
    'favoriteCacheSize': favoriteCache.length,
    'slowQueryCount': _slowQueryLogs.length,
  };

  List<SlowQueryLog> get slowQueryLogs => List.unmodifiable(_slowQueryLogs);

  Future<T> trackQuery<T>(
    String operation,
    Future<T> Function() query, {
    String? details,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await query();
    } finally {
      stopwatch.stop();
      final durationMs = stopwatch.elapsedMilliseconds;
      if (durationMs >= _slowQueryThresholdMs) {
        _slowQueryLogs.add(
          SlowQueryLog(
            operation: operation,
            durationMs: durationMs,
            timestamp: DateTime.now(),
            details: details,
          ),
        );
        if (_slowQueryLogs.length > _maxSlowQueryLogs) {
          _slowQueryLogs.removeAt(0);
        }
        AppLogger.w('Slow query: $operation took ${durationMs}ms', 'GalleryDS');
      }
    }
  }
}
