import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

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

@Riverpod(keepAlive: true)
class StatisticsNotifier extends _$StatisticsNotifier {
  Future<void>? _loadFuture;

  @override
  StatisticsData build() {
    unawaited(Future.microtask(_loadStatistics));
    return const StatisticsData();
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
            _hasCompleteDashboardData(cachedStatistics)) {
          state = StatisticsData(
            statistics: cachedStatistics,
            isLoading: true,
            lastUpdate: cachedStatistics.calculatedAt,
          );
        }
      }

      final snapshot = await dataSource.getDashboardStatistics();
      final statistics = ref
          .read(statisticsServiceProvider)
          .fromDashboardSnapshot(snapshot);

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

  bool _hasCompleteDashboardData(GalleryStatistics statistics) {
    if (statistics.totalImages == 0) return true;
    return statistics.dailyTrends.isNotEmpty &&
        statistics.hourlyDistribution.isNotEmpty &&
        statistics.weekdayDistribution.isNotEmpty;
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

  Future<void> preloadForWarmup() => _loadStatistics();
}
