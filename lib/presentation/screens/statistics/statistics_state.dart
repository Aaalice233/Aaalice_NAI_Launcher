import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../../data/models/gallery/gallery_statistics.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/repositories/local_gallery_repository.dart';
import '../../../data/services/statistics_cache_service.dart';
import '../../../data/services/statistics_service.dart';

part 'statistics_state.g.dart';

/// Statistics filter state
class StatisticsFilter {
  final DateTimeRange? dateRange;
  final String? selectedModel;
  final String? selectedResolution;
  final String timeGranularity;

  const StatisticsFilter({
    this.dateRange,
    this.selectedModel,
    this.selectedResolution,
    this.timeGranularity = 'day',
  });

  StatisticsFilter copyWith({
    DateTimeRange? dateRange,
    String? selectedModel,
    String? selectedResolution,
    String? timeGranularity,
    bool clearDateRange = false,
    bool clearModel = false,
    bool clearResolution = false,
  }) {
    return StatisticsFilter(
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      selectedModel: clearModel ? null : (selectedModel ?? this.selectedModel),
      selectedResolution: clearResolution
          ? null
          : (selectedResolution ?? this.selectedResolution),
      timeGranularity: timeGranularity ?? this.timeGranularity,
    );
  }

  bool get hasActiveFilters =>
      dateRange != null ||
      (selectedModel != null && selectedModel!.isNotEmpty) ||
      (selectedResolution != null && selectedResolution!.isNotEmpty);

  StatisticsFilter clear() => const StatisticsFilter();
}

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

  List<String> get availableModels {
    final models = allRecords
        .map((r) => r.metadata?.model)
        .whereType<String>()
        .toSet()
        .toList();
    models.sort();
    return models;
  }

  List<String> get availableResolutions {
    final resolutions = allRecords
        .where((r) => r.metadata != null && r.metadata!.hasData)
        .map((r) => '${r.metadata!.width}x${r.metadata!.height}')
        .toSet()
        .toList();
    resolutions.sort();
    return resolutions;
  }
}

/// Statistics notifier for managing state with caching
/// keepAlive: true ensures data persists when navigating away from statistics screen
@Riverpod(keepAlive: true)
class StatisticsNotifier extends _$StatisticsNotifier {
  StatisticsFilter _filter = const StatisticsFilter();

  // === Caching mechanism ===
  List<LocalImageRecord>? _cachedRecords;
  DateTime? _cacheTimestamp;
  static const _cacheValidDuration = Duration(minutes: 5);

  // Statistics result cache (by filter condition)
  final Map<String, GalleryStatistics> _statsCache = {};

  // Debounce timer for filter updates
  Timer? _debounceTimer;

  bool get _isCacheValid =>
      _cachedRecords != null &&
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < _cacheValidDuration;

  String _getCacheKey(StatisticsFilter filter) {
    return '${filter.dateRange?.start.millisecondsSinceEpoch}_'
        '${filter.dateRange?.end.millisecondsSinceEpoch}_'
        '${filter.selectedModel}_${filter.selectedResolution}';
  }

  @override
  StatisticsData build() {
    // Clean up timer on dispose
    ref.onDispose(() => _debounceTimer?.cancel());
    // Defer loading to avoid blocking UI during navigation
    Future.microtask(() => _loadStatistics());
    return const StatisticsData();
  }

  StatisticsFilter get filter => _filter;

  /// Main load method: prefer using cache
  Future<void> _loadStatistics() async {
    // Extra safety: yield to UI before starting
    await Future.delayed(const Duration(milliseconds: 50));

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Step 1: Load data (use cache if valid)
      await _ensureRecordsLoaded();

      // Step 2: Apply filter and compute statistics
      await _applyFilterAndCompute();
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

  /// Apply filter and compute statistics (with result caching)
  Future<void> _applyFilterAndCompute() async {
    final records = _cachedRecords ?? [];
    final filteredRecords = _applyFilters(records);
    final cacheKey = _getCacheKey(_filter);

    // Check statistics result cache
    if (_statsCache.containsKey(cacheKey)) {
      state = StatisticsData(
        allRecords: records,
        filteredRecords: filteredRecords,
        statistics: _statsCache[cacheKey],
        isLoading: false,
        lastUpdate: DateTime.now(),
      );
      return;
    }

    // Compute new statistics and cache
    final service = ref.read(statisticsServiceProvider);
    final statistics = await service.computeAllStatistics(filteredRecords);
    _statsCache[cacheKey] = statistics;

    // 如果是默认过滤器（无过滤条件），同步保存到持久化缓存
    if (!_filter.hasActiveFilters) {
      final cacheService = ref.read(statisticsCacheServiceProvider);
      await cacheService.saveCache(statistics, records.length);
    }

    state = StatisticsData(
      allRecords: records,
      filteredRecords: filteredRecords,
      statistics: statistics,
      isLoading: false,
      lastUpdate: DateTime.now(),
    );
  }

  List<LocalImageRecord> _applyFilters(List<LocalImageRecord> records) {
    var filtered = records;

    if (_filter.dateRange != null) {
      filtered = filtered.where((record) {
        final fileDate = record.modifiedAt;
        return !fileDate.isBefore(_filter.dateRange!.start) &&
            !fileDate.isAfter(_filter.dateRange!.end);
      }).toList();
    }

    if (_filter.selectedModel != null && _filter.selectedModel!.isNotEmpty) {
      filtered = filtered.where((record) {
        return record.metadata?.model == _filter.selectedModel;
      }).toList();
    }

    if (_filter.selectedResolution != null &&
        _filter.selectedResolution!.isNotEmpty) {
      filtered = filtered.where((record) {
        if (record.metadata == null) return false;
        final resolution =
            '${record.metadata!.width}x${record.metadata!.height}';
        return resolution == _filter.selectedResolution;
      }).toList();
    }

    return filtered;
  }

  /// Schedule filter update with debounce
  void _scheduleFilterUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilterAndCompute();
    });
  }

  void updateFilter(StatisticsFilter newFilter) {
    _filter = newFilter;
    state = state.copyWith(isLoading: true);
    _scheduleFilterUpdate();
  }

  void setDateRange(DateTimeRange? range) {
    _filter = _filter.copyWith(dateRange: range, clearDateRange: range == null);
    state = state.copyWith(isLoading: true);
    _scheduleFilterUpdate();
  }

  void setModel(String? model) {
    _filter = _filter.copyWith(
      selectedModel: model,
      clearModel: model == null || model.isEmpty,
    );
    state = state.copyWith(isLoading: true);
    _scheduleFilterUpdate();
  }

  void setResolution(String? resolution) {
    _filter = _filter.copyWith(
      selectedResolution: resolution,
      clearResolution: resolution == null || resolution.isEmpty,
    );
    state = state.copyWith(isLoading: true);
    _scheduleFilterUpdate();
  }

  void setTimeGranularity(String granularity) {
    _filter = _filter.copyWith(timeGranularity: granularity);
    state = state.copyWith(); // Trigger rebuild without reloading data
  }

  void clearFilters() {
    _filter = const StatisticsFilter();
    state = state.copyWith(isLoading: true);
    _scheduleFilterUpdate();
  }

  /// Force refresh: clear all caches
  Future<void> refresh() async {
    _cachedRecords = null;
    _cacheTimestamp = null;
    _statsCache.clear();
    // 清除持久化缓存
    final cacheService = ref.read(statisticsCacheServiceProvider);
    await cacheService.clearCache();
    await _loadStatistics();
  }

  /// 预热阶段专用：预加载数据但不触发UI更新
  ///
  /// 在应用启动时调用，将统计数据预先加载到缓存中，
  /// 以便用户打开统计页面时能立即看到数据。
  Future<void> preloadForWarmup() async {
    try {
      final cacheService = ref.read(statisticsCacheServiceProvider);
      final repository = LocalGalleryRepository.instance;

      // Step 1: 快速获取当前图片数量
      final files = await repository.getAllImageFiles();
      final currentImageCount = files.length;

      // Step 2: 尝试从持久化缓存加载
      final cachedStats = cacheService.getCache();
      if (cachedStats != null && cacheService.isCacheValid(currentImageCount)) {
        // 缓存命中，直接使用
        final cacheKey = _getCacheKey(const StatisticsFilter());
        _statsCache[cacheKey] = cachedStats;
        AppLogger.i(
          'Statistics loaded from persistent cache: $currentImageCount images',
          'Warmup',
        );
        return;
      }

      // Step 3: 缓存未命中或过期，执行完整计算
      AppLogger.i(
        'Statistics cache miss, computing for $currentImageCount images',
        'Warmup',
      );

      // 加载记录到内存缓存
      await _ensureRecordsLoaded();

      final records = _cachedRecords ?? [];
      if (records.isEmpty) {
        AppLogger.i('Statistics preload: no records found', 'Warmup');
        return;
      }

      // 使用默认过滤器预计算统计
      final service = ref.read(statisticsServiceProvider);
      final statistics = await service.computeAllStatistics(records);

      // 缓存结果到内存
      final cacheKey = _getCacheKey(const StatisticsFilter());
      _statsCache[cacheKey] = statistics;

      // Step 4: 保存到持久化缓存
      await cacheService.saveCache(statistics, records.length);

      AppLogger.i(
        'Statistics preloaded and cached: ${records.length} records',
        'Warmup',
      );
    } catch (e) {
      AppLogger.w('Statistics preload failed: $e', 'Warmup');
      // 不抛出异常，允许预热继续
    }
  }
}
