import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/cache/gallery_cache_manager.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/database/datasources/gallery_data_source.dart' as ds;
import '../../../core/utils/app_logger.dart';
import '../../../data/models/gallery/gallery_statistics.dart';
import '../../../data/services/statistics_cache_service.dart';
import '../../../data/services/statistics_service.dart';

part 'statistics_state.g.dart';

class StatisticsData {
  final GalleryStatistics? statistics;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdate;

  const StatisticsData({
    this.statistics,
    this.isLoading = true,
    this.error,
    this.lastUpdate,
  });

  StatisticsData copyWith({
    GalleryStatistics? statistics,
    bool? isLoading,
    String? error,
    DateTime? lastUpdate,
    bool clearError = false,
  }) {
    return StatisticsData(
      statistics: statistics ?? this.statistics,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// Whether cached statistics can be shown as-is; caches missing newer
/// aggregates still load but are shown only after a fresh aggregation.
bool hasCompleteDashboardStatistics(GalleryStatistics statistics) {
  if (statistics.totalImages == 0) return true;
  return statistics.dailyTrends.isNotEmpty &&
      statistics.hourlyDistribution.isNotEmpty &&
      statistics.weekdayDistribution.isNotEmpty &&
      // Pre-parameter caches have samplers but no parameter distribution.
      (statistics.samplerDistribution.isEmpty ||
          statistics.parameterDistribution.isNotEmpty);
}

@Riverpod(keepAlive: true)
class StatisticsNotifier extends _$StatisticsNotifier {
  Future<void>? _loadFuture;
  bool _needsRefreshAfterWarmup = false;

  /// Gallery index writes arriving within this window share one reload.
  static const Duration galleryChangeDebounce = Duration(seconds: 1);

  // Bumped on every gallery index write; data loaded at an older revision is
  // stale.
  int _galleryRevision = 0;
  int _loadedRevision = 0;
  // Only a visible page reloads on writes; a hidden one catches up when shown.
  bool _visible = false;
  Timer? _galleryChangeTimer;

  bool get _missesGalleryChanges => _loadedRevision != _galleryRevision;

  @override
  StatisticsData build() {
    final cacheManager = GalleryCacheManager();
    cacheManager.registerOnStatisticsInvalidated(_onGalleryIndexChanged);
    ref.onDispose(() {
      _cancelPendingReload();
      cacheManager.unregisterOnStatisticsInvalidated(_onGalleryIndexChanged);
    });
    return const StatisticsData();
  }

  Future<void> whenLoaded() {
    if (state.statistics == null) return _loadStatistics();
    if (!_needsRefreshAfterWarmup && !_missesGalleryChanges) {
      return Future<void>.value();
    }
    _needsRefreshAfterWarmup = false;
    return _loadStatistics(usePersistentCache: false);
  }

  /// Set by the statistics page: shell branches stay mounted and keep
  /// watching while hidden, so listeners cannot tell whether it is on screen.
  Future<void> setVisible(bool visible) {
    _visible = visible;
    if (visible) return whenLoaded();
    _cancelPendingReload();
    return Future<void>.value();
  }

  void _onGalleryIndexChanged() {
    _galleryRevision++;
    if (!_visible) return;
    _galleryChangeTimer?.cancel();
    _galleryChangeTimer = Timer(galleryChangeDebounce, () {
      _galleryChangeTimer = null;
      unawaited(_reloadAfterGalleryChange());
    });
  }

  Future<void> _reloadAfterGalleryChange() async {
    final inFlight = _loadFuture;
    if (inFlight != null) await inFlight;
    if (!_visible || !_missesGalleryChanges) return;
    await _loadStatistics(usePersistentCache: false);
  }

  void _cancelPendingReload() {
    _galleryChangeTimer?.cancel();
    _galleryChangeTimer = null;
  }

  Future<void> _loadStatistics({bool usePersistentCache = true}) async {
    final existingLoad = _loadFuture;
    if (existingLoad != null) {
      await existingLoad;
      return;
    }

    final load = _performLoad(usePersistentCache: usePersistentCache);
    _loadFuture = load;
    try {
      await load;
    } finally {
      if (identical(_loadFuture, load)) {
        _loadFuture = null;
      }
    }
  }

  Future<void> _performLoad({required bool usePersistentCache}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final stopwatch = Stopwatch()..start();

    try {
      final dataSource = await _getDataSource();
      final cacheService = ref.read(statisticsCacheServiceProvider);

      if (usePersistentCache && state.statistics == null) {
        final imageCount = await dataSource.countImages();
        final cachedStatistics = cacheService.getCache();
        if (cachedStatistics != null &&
            cacheService.isCacheValid(imageCount) &&
            hasCompleteDashboardStatistics(cachedStatistics)) {
          state = StatisticsData(
            statistics: cachedStatistics,
            isLoading: true,
            lastUpdate: cachedStatistics.calculatedAt,
          );
        }
      }

      // Taken before the query: a write racing it costs one extra reload at
      // most, never a missed one.
      final revision = _galleryRevision;
      final snapshot = await dataSource.getDashboardStatistics();
      final statistics = ref
          .read(statisticsServiceProvider)
          .fromDashboardSnapshot(snapshot);

      _needsRefreshAfterWarmup = false;
      _loadedRevision = revision;
      state = StatisticsData(
        statistics: statistics,
        isLoading: false,
        lastUpdate: statistics.calculatedAt,
      );

      stopwatch.stop();
      AppLogger.i(
        'Dashboard statistics loaded in ${stopwatch.elapsedMilliseconds}ms '
            'for ${statistics.totalImages} images',
        'Statistics',
      );

      // Yield after publishing state so cache serialization cannot delay paint.
      await Future<void>.delayed(Duration.zero);
      await cacheService.saveCache(statistics, statistics.totalImages);
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.e(
        'Failed to load dashboard statistics',
        e,
        stack,
        'Statistics',
      );
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<ds.GalleryDataSource> _getDataSource() async {
    final dbManager = await ref.read(databaseManagerProvider.future);
    final dataSource = dbManager.getDataSource<ds.GalleryDataSource>('gallery');
    if (dataSource == null) {
      throw StateError('GalleryDataSource not found');
    }
    return dataSource;
  }

  Future<void> refresh() async {
    final currentLoad = _loadFuture;
    if (currentLoad != null) {
      await currentLoad;
    }

    final cacheService = ref.read(statisticsCacheServiceProvider);
    await cacheService.clearCache();
    await _loadStatistics(usePersistentCache: false);
  }

  Future<void> preloadForWarmup() async {
    final existingLoad = _loadFuture;
    if (existingLoad != null) {
      await existingLoad;
      return;
    }

    final load = _restoreCacheOrLoadStatistics();
    _loadFuture = load;
    try {
      await load;
    } finally {
      if (identical(_loadFuture, load)) {
        _loadFuture = null;
      }
    }
  }

  Future<void> _restoreCacheOrLoadStatistics() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final dataSource = await _getDataSource();
      final cacheService = ref.read(statisticsCacheServiceProvider);
      final imageCount = await dataSource.countImages();
      final cachedStatistics = cacheService.getCache();
      if (cachedStatistics != null &&
          cacheService.isCacheValid(imageCount) &&
          hasCompleteDashboardStatistics(cachedStatistics)) {
        _needsRefreshAfterWarmup = true;
        state = StatisticsData(
          statistics: cachedStatistics,
          isLoading: false,
          lastUpdate: cachedStatistics.calculatedAt,
        );
        AppLogger.i(
          'Restored warmup statistics cache for $imageCount images',
          'Statistics',
        );
        return;
      }
      await _performLoad(usePersistentCache: false);
    } catch (e, stack) {
      AppLogger.e(
        'Failed to restore warmup statistics',
        e,
        stack,
        'Statistics',
      );
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}
