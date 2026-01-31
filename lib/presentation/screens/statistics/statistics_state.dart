import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/gallery/gallery_statistics.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/repositories/local_gallery_repository.dart';
import '../../../data/services/statistics_cache_service.dart';
import '../../../data/services/statistics_service.dart';

part 'statistics_state.g.dart';

/// Statistics data state
class StatisticsData {
  final List<LocalImageRecord> allRecords;
  final List<LocalImageRecord> filteredRecords;
  final GalleryStatistics? statistics;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdate;

  const StatisticsData({
    this.allRecords = const [],
    this.filteredRecords = const [],
    this.statistics,
    this.isLoading = true,
    this.error,
    this.lastUpdate,
  });

  StatisticsData copyWith({
    List<LocalImageRecord>? allRecords,
    List<LocalImageRecord>? filteredRecords,
    GalleryStatistics? statistics,
    bool? isLoading,
    String? error,
    DateTime? lastUpdate,
    bool clearError = false,
  }) {
    return StatisticsData(
      allRecords: allRecords ?? this.allRecords,
      filteredRecords: filteredRecords ?? this.filteredRecords,
      statistics: statistics ?? this.statistics,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}

/// Statistics notifier for managing state with caching
/// keepAlive: true ensures data persists when navigating away from statistics screen
@Riverpod(keepAlive: true)
class StatisticsNotifier extends _$StatisticsNotifier {
  // === Caching mechanism ===
  List<LocalImageRecord>? _cachedRecords;
  DateTime? _cacheTimestamp;
  static const _cacheValidDuration = Duration(minutes: 5);
  static const _defaultCacheKey = 'default';

  // Statistics result cache
  final Map<String, GalleryStatistics> _statsCache = {};

  bool get _isCacheValid =>
      _cachedRecords != null &&
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < _cacheValidDuration;

  @override
  StatisticsData build() {
    // Defer loading to avoid blocking UI during navigation
    Future.microtask(() => _loadStatistics());
    return const StatisticsData();
  }

  /// Main load method: prefer using cache
  Future<void> _loadStatistics() async {
    // Extra safety: yield to UI before starting
    await Future.delayed(const Duration(milliseconds: 50));

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Step 1: Load data (use cache if valid)
      await _ensureRecordsLoaded();

      // Step 2: Compute statistics
      await _computeStatistics();
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  /// Ensure records are loaded (with caching)
  Future<void> _ensureRecordsLoaded() async {
    if (_isCacheValid) return;

    final repository = LocalGalleryRepository.instance;

    // Get files directly from repository
    final files = await repository.getAllImageFiles();

    // Batch load records to avoid UI freeze
    const batchSize = 50;
    final allRecords = <LocalImageRecord>[];

    for (var i = 0; i < files.length; i += batchSize) {
      final end = min(i + batchSize, files.length);
      final batch = files.sublist(i, end);
      final records = await repository.loadRecords(batch);
      allRecords.addAll(records);

      // Yield to UI thread more frequently
      await Future.delayed(Duration.zero);
    }

    _cachedRecords = allRecords;
    _cacheTimestamp = DateTime.now();
  }

  /// Compute statistics (with result caching)
  Future<void> _computeStatistics() async {
    final records = _cachedRecords ?? [];

    // Check statistics result cache
    if (_statsCache.containsKey(_defaultCacheKey)) {
      state = StatisticsData(
        allRecords: records,
        filteredRecords: records,
        statistics: _statsCache[_defaultCacheKey],
        isLoading: false,
        lastUpdate: DateTime.now(),
      );
      return;
    }

    // Compute new statistics and cache
    final service = ref.read(statisticsServiceProvider);
    final statistics = await service.computeAllStatistics(records);
    _statsCache[_defaultCacheKey] = statistics;

    // Save to persistent cache
    final cacheService = ref.read(statisticsCacheServiceProvider);
    await cacheService.saveCache(statistics, records.length);

    state = StatisticsData(
      allRecords: records,
      filteredRecords: records,
      statistics: statistics,
      isLoading: false,
      lastUpdate: DateTime.now(),
    );
  }

  /// Force refresh: clear all caches
  Future<void> refresh() async {
    _cachedRecords = null;
    _cacheTimestamp = null;
    _statsCache.clear();
    // Clear persistent cache
    final cacheService = ref.read(statisticsCacheServiceProvider);
    await cacheService.clearCache();
    await _loadStatistics();
  }

  /// Preload for warmup: preload data without triggering UI updates
  ///
  /// Called during app startup to preload statistics data into cache,
  /// so users see data immediately when opening the statistics page.
  Future<void> preloadForWarmup() async {
    try {
      final cacheService = ref.read(statisticsCacheServiceProvider);
      final repository = LocalGalleryRepository.instance;

      // Step 1: Quickly get current image count
      final files = await repository.getAllImageFiles();
      final currentImageCount = files.length;

      // Step 2: Try loading from persistent cache
      final cachedStats = cacheService.getCache();
      if (cachedStats != null && cacheService.isCacheValid(currentImageCount)) {
        // Cache hit, use directly
        _statsCache[_defaultCacheKey] = cachedStats;
        AppLogger.i(
          'Statistics loaded from persistent cache: $currentImageCount images',
          'Warmup',
        );
        return;
      }

      // Step 3: Cache miss or expired, perform full computation
      AppLogger.i(
        'Statistics cache miss, computing for $currentImageCount images',
        'Warmup',
      );

      // Load records into memory cache
      await _ensureRecordsLoaded();

      final records = _cachedRecords ?? [];
      if (records.isEmpty) {
        AppLogger.i('Statistics preload: no records found', 'Warmup');
        return;
      }

      // Compute statistics
      final service = ref.read(statisticsServiceProvider);
      final statistics = await service.computeAllStatistics(records);

      // Cache result in memory
      _statsCache[_defaultCacheKey] = statistics;

      // Step 4: Save to persistent cache
      await cacheService.saveCache(statistics, records.length);

      AppLogger.i(
        'Statistics preloaded and cached: ${records.length} records',
        'Warmup',
      );
    } catch (e) {
      AppLogger.w('Statistics preload failed: $e', 'Warmup');
      // Don't throw, allow warmup to continue
    }
  }
}
