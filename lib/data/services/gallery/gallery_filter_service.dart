import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/database/utils/lru_cache.dart';
import '../../../core/exceptions/gallery_exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/isolate_pool.dart';
import '../../../core/utils/tag_normalizer.dart';
import 'gallery_path_utils.dart';

export 'gallery_filter_service.dart' show FilterCriteria;

/// 过滤条件
@immutable
class FilterCriteria {
  final String searchQuery;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final bool showFavoritesOnly;
  final List<String> selectedTags;
  final String? filterModel;
  final String? filterSampler;
  final int? filterMinSteps;
  final int? filterMaxSteps;
  final double? filterMinCfg;
  final double? filterMaxCfg;
  final String? filterResolution;
  final int? minWidth;
  final int? minHeight;
  final int? maxWidth;
  final int? maxHeight;
  final int? minFileSize;
  final int? maxFileSize;
  final List<String> metadataStatuses;

  /// 分类过滤
  final String? categoryId;
  final String? categoryFolderPath;

  /// 相簿过滤（'favorites' 表示收藏相簿，其余为相簿 id）
  final String? albumId;

  const FilterCriteria({
    this.searchQuery = '',
    this.dateStart,
    this.dateEnd,
    this.showFavoritesOnly = false,
    this.selectedTags = const [],
    this.filterModel,
    this.filterSampler,
    this.filterMinSteps,
    this.filterMaxSteps,
    this.filterMinCfg,
    this.filterMaxCfg,
    this.filterResolution,
    this.minWidth,
    this.minHeight,
    this.maxWidth,
    this.maxHeight,
    this.minFileSize,
    this.maxFileSize,
    this.metadataStatuses = const [],
    this.categoryId,
    this.categoryFolderPath,
    this.albumId,
  });

  FilterCriteria copyWith({
    String? searchQuery,
    DateTime? dateStart,
    DateTime? dateEnd,
    bool? showFavoritesOnly,
    List<String>? selectedTags,
    String? filterModel,
    String? filterSampler,
    int? filterMinSteps,
    int? filterMaxSteps,
    double? filterMinCfg,
    double? filterMaxCfg,
    String? filterResolution,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
    int? minFileSize,
    int? maxFileSize,
    List<String>? metadataStatuses,
    bool clearDateStart = false,
    bool clearDateEnd = false,
    bool clearFilterModel = false,
    bool clearFilterSampler = false,
    bool clearFilterMinSteps = false,
    bool clearFilterMaxSteps = false,
    bool clearFilterMinCfg = false,
    bool clearFilterMaxCfg = false,
    bool clearFilterResolution = false,
    bool clearMinWidth = false,
    bool clearMinHeight = false,
    bool clearMaxWidth = false,
    bool clearMaxHeight = false,
    bool clearMinFileSize = false,
    bool clearMaxFileSize = false,
    String? categoryId,
    String? categoryFolderPath,
    bool clearCategoryId = false,
    bool clearCategoryFolderPath = false,
    String? albumId,
    bool clearAlbumId = false,
  }) {
    return FilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      dateStart: clearDateStart ? null : (dateStart ?? this.dateStart),
      dateEnd: clearDateEnd ? null : (dateEnd ?? this.dateEnd),
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      selectedTags: selectedTags ?? this.selectedTags,
      filterModel: clearFilterModel ? null : (filterModel ?? this.filterModel),
      filterSampler: clearFilterSampler
          ? null
          : (filterSampler ?? this.filterSampler),
      filterMinSteps: clearFilterMinSteps
          ? null
          : (filterMinSteps ?? this.filterMinSteps),
      filterMaxSteps: clearFilterMaxSteps
          ? null
          : (filterMaxSteps ?? this.filterMaxSteps),
      filterMinCfg: clearFilterMinCfg
          ? null
          : (filterMinCfg ?? this.filterMinCfg),
      filterMaxCfg: clearFilterMaxCfg
          ? null
          : (filterMaxCfg ?? this.filterMaxCfg),
      filterResolution: clearFilterResolution
          ? null
          : (filterResolution ?? this.filterResolution),
      minWidth: clearMinWidth ? null : (minWidth ?? this.minWidth),
      minHeight: clearMinHeight ? null : (minHeight ?? this.minHeight),
      maxWidth: clearMaxWidth ? null : (maxWidth ?? this.maxWidth),
      maxHeight: clearMaxHeight ? null : (maxHeight ?? this.maxHeight),
      minFileSize: clearMinFileSize ? null : (minFileSize ?? this.minFileSize),
      maxFileSize: clearMaxFileSize ? null : (maxFileSize ?? this.maxFileSize),
      metadataStatuses: metadataStatuses ?? this.metadataStatuses,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      categoryFolderPath: clearCategoryFolderPath
          ? null
          : (categoryFolderPath ?? this.categoryFolderPath),
      albumId: clearAlbumId ? null : (albumId ?? this.albumId),
    );
  }

  bool get hasFilters =>
      searchQuery.isNotEmpty ||
      dateStart != null ||
      dateEnd != null ||
      showFavoritesOnly ||
      selectedTags.isNotEmpty ||
      filterModel != null ||
      filterSampler != null ||
      filterMinSteps != null ||
      filterMaxSteps != null ||
      filterMinCfg != null ||
      filterMaxCfg != null ||
      filterResolution != null ||
      minWidth != null ||
      minHeight != null ||
      maxWidth != null ||
      maxHeight != null ||
      minFileSize != null ||
      maxFileSize != null ||
      metadataStatuses.isNotEmpty ||
      categoryId != null ||
      categoryFolderPath != null ||
      albumId != null;

  bool get hasMetadataFilters =>
      filterModel != null ||
      filterSampler != null ||
      filterResolution != null ||
      filterMinSteps != null ||
      filterMaxSteps != null ||
      filterMinCfg != null ||
      filterMaxCfg != null;

  bool get hasAdvancedFilters =>
      minWidth != null ||
      minHeight != null ||
      maxWidth != null ||
      maxHeight != null ||
      minFileSize != null ||
      maxFileSize != null ||
      metadataStatuses.isNotEmpty;

  /// 生成缓存键
  String get cacheKey {
    final parts = <String>[
      'q:${searchQuery.toLowerCase().trim()}',
      if (dateStart != null) 'ds:${dateStart!.millisecondsSinceEpoch}',
      if (dateEnd != null) 'de:${dateEnd!.millisecondsSinceEpoch}',
      if (showFavoritesOnly) 'fav:1',
      if (selectedTags.isNotEmpty) 'tags:${selectedTags.join(",")}',
      if (filterModel != null) 'model:$filterModel',
      if (filterSampler != null) 'sampler:$filterSampler',
      if (filterMinSteps != null) 'minStep:$filterMinSteps',
      if (filterMaxSteps != null) 'maxStep:$filterMaxSteps',
      if (filterMinCfg != null) 'minCfg:$filterMinCfg',
      if (filterMaxCfg != null) 'maxCfg:$filterMaxCfg',
      if (filterResolution != null) 'res:$filterResolution',
      if (minWidth != null) 'minW:$minWidth',
      if (minHeight != null) 'minH:$minHeight',
      if (maxWidth != null) 'maxW:$maxWidth',
      if (maxHeight != null) 'maxH:$maxHeight',
      if (minFileSize != null) 'minFS:$minFileSize',
      if (maxFileSize != null) 'maxFS:$maxFileSize',
      if (metadataStatuses.isNotEmpty) 'meta:${metadataStatuses.join(",")}',
      if (categoryId != null) 'catId:$categoryId',
      if (categoryFolderPath != null) 'catPath:$categoryFolderPath',
      if (albumId != null) 'album:$albumId',
    ];
    return parts.join('|');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterCriteria && other.cacheKey == cacheKey;
  }

  @override
  int get hashCode => cacheKey.hashCode;
}

/// 过滤结果
@immutable
class FilterResult {
  final List<File> files;
  final int totalCount;
  final Duration executionTime;
  final bool fromCache;
  final FilterCriteria criteria;

  const FilterResult({
    required this.files,
    required this.totalCount,
    required this.executionTime,
    this.fromCache = false,
    required this.criteria,
  });

  FilterResult copyWith({
    List<File>? files,
    int? totalCount,
    Duration? executionTime,
    bool? fromCache,
    FilterCriteria? criteria,
  }) {
    return FilterResult(
      files: files ?? this.files,
      totalCount: totalCount ?? this.totalCount,
      executionTime: executionTime ?? this.executionTime,
      fromCache: fromCache ?? this.fromCache,
      criteria: criteria ?? this.criteria,
    );
  }
}

/// 画廊过滤服务
///
/// 提供异步过滤、缓存和多条件组合查询功能。
/// 所有过滤操作都是异步的，避免阻塞 UI 线程。
class GalleryFilterService {
  final GalleryDataSource _dataSource;

  // 过滤结果缓存
  static const int _maxCacheSize = 50;
  final LRUCache<String, FilterResult> _filterCache = LRUCache(
    maxSize: _maxCacheSize,
  );

  // 取消令牌
  final Map<String, CancelToken> _activeFilters = {};

  GalleryFilterService(this._dataSource);

  /// 获取缓存统计
  Map<String, dynamic> get cacheStatistics => _filterCache.statistics;

  /// 清除缓存
  void clearCache() {
    _filterCache.clear();
    AppLogger.i('Filter cache cleared', 'GalleryFilterService');
  }

  String _buildCacheKey(List<File> allFiles, FilterCriteria criteria) {
    return '${criteria.cacheKey}|files:${allFiles.length}|rev:${_dataSource.dataRevision}';
  }

  /// 异步应用过滤条件
  ///
  /// [allFiles] 所有文件列表
  /// [criteria] 过滤条件
  /// [operationId] 操作 ID（用于取消）
  Future<FilterResult> applyFilters(
    List<File> allFiles,
    FilterCriteria criteria, {
    String? operationId,
  }) async {
    final id = operationId ?? 'filter_${DateTime.now().millisecondsSinceEpoch}';
    final stopwatch = Stopwatch()..start();

    // 创建取消令牌
    final cancelToken = CancelToken();
    _activeFilters[id] = cancelToken;

    try {
      // 检查缓存
      final cacheKey = _buildCacheKey(allFiles, criteria);
      final cached = _filterCache.get(cacheKey);
      if (cached != null) {
        AppLogger.d('Filter cache hit: $cacheKey', 'GalleryFilterService');
        return cached.copyWith(fromCache: true);
      }

      // 【调试】记录过滤前状态
      AppLogger.d(
        'applyFilters START: allFiles=${allFiles.length}, hasFilters=${criteria.hasFilters}, cacheKey=$cacheKey',
        'GalleryFilterService',
      );

      // 无过滤条件
      if (!criteria.hasFilters) {
        final result = FilterResult(
          files: allFiles,
          totalCount: allFiles.length,
          executionTime: stopwatch.elapsed,
          criteria: criteria,
        );
        _filterCache.put(cacheKey, result);
        AppLogger.d(
          'applyFilters NO FILTERS: returning ${allFiles.length} files',
          'GalleryFilterService',
        );
        return result;
      }

      // 检查是否取消
      if (cancelToken.isCancelled) {
        throw const FilterCancelledException();
      }

      // 执行过滤
      final filtered = await _runFilterPipeline(
        allFiles,
        criteria,
        cancelToken,
      );

      // 检查是否取消
      if (cancelToken.isCancelled) {
        throw const FilterCancelledException();
      }

      stopwatch.stop();

      final result = FilterResult(
        files: filtered,
        totalCount: filtered.length,
        executionTime: stopwatch.elapsed,
        criteria: criteria,
      );

      // 缓存结果
      _filterCache.put(cacheKey, result);

      AppLogger.d(
        'Filter completed in ${stopwatch.elapsedMilliseconds}ms: ${filtered.length} results (from ${allFiles.length} files)'
            ' | search="${criteria.searchQuery}" | tags=${criteria.selectedTags} | fav=${criteria.showFavoritesOnly}',
        'GalleryFilterService',
      );

      return result;
    } finally {
      _activeFilters.remove(id);
    }
  }

  /// 过滤管线：数据库批量条件 → 逗号分段搜索 → 本地路径与文件条件。
  Future<List<File>> _runFilterPipeline(
    List<File> allFiles,
    FilterCriteria criteria,
    CancelToken cancelToken,
  ) async {
    final plan = _planFilters(criteria);
    var filtered = allFiles;

    final databaseCriteria = plan.databaseCriteria;
    if (databaseCriteria != null) {
      filtered = await _searchInDatabase(
        filtered,
        databaseCriteria,
        cancelToken,
      );
      if (cancelToken.isCancelled) return [];
      AppLogger.d(
        'Filter pipeline after index query: ${filtered.length} files',
        'GalleryFilterService',
      );
    }

    final delimitedQuery = plan.delimitedSearchQuery;
    if (delimitedQuery != null) {
      filtered = await _filterByDelimitedSearchQuery(
        filtered,
        delimitedQuery,
        cancelToken,
      );
      if (cancelToken.isCancelled) return [];
      AppLogger.d(
        'Filter pipeline after delimited search: ${filtered.length} files',
        'GalleryFilterService',
      );
    }

    filtered = await _applyLocalFilters(
      filtered,
      criteria,
      cancelToken,
      applyDateRange: plan.applyLocalDateRange,
    );
    AppLogger.d(
      'Filter pipeline after local filters: ${filtered.length} files',
      'GalleryFilterService',
    );

    return filtered;
  }

  /// 把过滤条件分配到管线的各个阶段。
  _FilterPlan _planFilters(FilterCriteria criteria) {
    // 逗号分隔搜索改走分段 AND 匹配，避免 FTS 多词搜索的 OR 语义。
    final isDelimited =
        criteria.searchQuery.isNotEmpty &&
        _hasDelimitedSearchQuery(criteria.searchQuery);
    final databaseCriteria = isDelimited
        ? criteria.copyWith(searchQuery: '')
        : criteria;
    final usesDatabase = _requiresDatabaseStage(databaseCriteria);

    return _FilterPlan(
      databaseCriteria: usesDatabase ? databaseCriteria : null,
      delimitedSearchQuery: isDelimited ? criteria.searchQuery : null,
      // 索引查询在跑时顺带按 modified_at 过滤；否则回到文件修改时间，
      // 让尚未入库的图片仍能参与日期筛选。
      applyLocalDateRange:
          !usesDatabase &&
          (criteria.dateStart != null || criteria.dateEnd != null),
    );
  }

  /// 只能由索引回答的条件；日期区间不在其中，未入库图片也应能按文件时间筛选。
  bool _requiresDatabaseStage(FilterCriteria criteria) {
    return criteria.searchQuery.trim().isNotEmpty ||
        criteria.showFavoritesOnly ||
        criteria.hasAdvancedFilters ||
        criteria.hasMetadataFilters;
  }

  /// 在数据库中批量应用索引支持的条件
  Future<List<File>> _searchInDatabase(
    List<File> allFiles,
    FilterCriteria criteria,
    CancelToken cancelToken,
  ) async {
    if (allFiles.isEmpty) return allFiles;

    try {
      final imageIds = await _dataSource.advancedSearch(
        textQuery: criteria.searchQuery.toLowerCase().trim(),
        favoritesOnly: criteria.showFavoritesOnly,
        dateStart: criteria.dateStart,
        dateEnd: criteria.dateEnd,
        minWidth: criteria.minWidth,
        minHeight: criteria.minHeight,
        maxWidth: criteria.maxWidth,
        maxHeight: criteria.maxHeight,
        minFileSize: criteria.minFileSize,
        maxFileSize: criteria.maxFileSize,
        metadataStatuses: criteria.metadataStatuses.isNotEmpty
            ? criteria.metadataStatuses
            : null,
        model: criteria.filterModel,
        sampler: criteria.filterSampler,
        minSteps: criteria.filterMinSteps,
        maxSteps: criteria.filterMaxSteps,
        minCfgScale: criteria.filterMinCfg,
        maxCfgScale: criteria.filterMaxCfg,
        resolution: criteria.filterResolution,
        limit: max(1, allFiles.length),
      );

      if (cancelToken.isCancelled) return [];

      final images = await _dataSource.getImagesByIds(imageIds);
      final matchedKeys = {
        for (final image in images) galleryFilePathKey(image.filePath),
      };

      // 未入库的图片无法满足索引条件，这里一并排除。
      return allFiles
          .where((file) => matchedKeys.contains(galleryFilePathKey(file.path)))
          .toList();
    } catch (e, stack) {
      throw _filterFailure(
        criteria.cacheKey,
        'Failed to query the gallery index',
        e,
        stack,
      );
    }
  }

  /// 应用索引之外、只能在本地判定的条件
  Future<List<File>> _applyLocalFilters(
    List<File> allFiles,
    FilterCriteria criteria,
    CancelToken cancelToken, {
    required bool applyDateRange,
  }) async {
    var filtered = allFiles;

    // 标签过滤（需要数据库查询）
    if (criteria.selectedTags.isNotEmpty) {
      filtered = await _filterByTags(
        filtered,
        criteria.selectedTags,
        cancelToken,
      );
    }

    if (cancelToken.isCancelled) return [];

    // 日期过滤（按文件修改时间）
    if (applyDateRange) {
      filtered = await _filterByDateRange(filtered, criteria, cancelToken);
    }

    if (cancelToken.isCancelled) return [];

    // 分类过滤（按文件夹路径）
    if (criteria.categoryFolderPath != null) {
      filtered = await _filterByCategory(
        filtered,
        criteria.categoryFolderPath!,
        cancelToken,
      );
    }

    if (cancelToken.isCancelled) return [];

    // 相簿过滤（逻辑引用集合，含子相簿）
    if (criteria.albumId != null) {
      filtered = await _filterByAlbum(filtered, criteria.albumId!, cancelToken);
    }

    return filtered;
  }

  /// 条件失败时保留条件本身并向上抛出，避免静默返回未过滤结果。
  GalleryFilterException _filterFailure(
    String criteriaDetail,
    String message,
    Object error,
    StackTrace stack,
  ) {
    AppLogger.e(message, error, stack, 'GalleryFilterService');
    return GalleryFilterException(
      filterCriteria: criteriaDetail,
      message: message,
      cause: error,
    );
  }

  /// 按逗号分隔的搜索片段做 AND 包含匹配。
  Future<List<File>> _filterByDelimitedSearchQuery(
    List<File> files,
    String searchQuery,
    CancelToken cancelToken,
  ) async {
    final segments = _parseDelimitedSearchSegments(searchQuery);
    if (segments.isEmpty || files.isEmpty) return files;

    try {
      final imageIds = await _dataSource.searchByDelimitedTextSegments(
        segments,
        limit: max(1, files.length),
        candidatePaths: files.map((file) => file.path).toList(),
      );

      if (cancelToken.isCancelled) return [];

      final images = await _dataSource.getImagesByIds(imageIds);
      final matchedKeys = {
        for (final image in images) galleryFilePathKey(image.filePath),
      };

      return files.where((file) {
        if (cancelToken.isCancelled) return false;
        return matchedKeys.contains(galleryFilePathKey(file.path));
      }).toList();
    } catch (e, stack) {
      throw _filterFailure(
        'delimitedSearch:$searchQuery',
        'Failed to filter by delimited search query',
        e,
        stack,
      );
    }
  }

  /// 按标签过滤
  Future<List<File>> _filterByTags(
    List<File> files,
    List<String> tags,
    CancelToken cancelToken,
  ) async {
    try {
      final requiredTags = tags
          .map(TagNormalizer.normalizeTagForMatch)
          .where((tag) => tag.isNotEmpty)
          .toSet();
      if (requiredTags.isEmpty) return files;

      // 获取文件路径到图片 ID 的映射
      final pathToIdMap = await _dataSource.getImageIdsByPaths(
        files.map((f) => f.path).toList(),
      );

      // 获取所有图片的标签
      final imageIds = pathToIdMap.values.whereType<int>().toList();
      final tagsMap = await _dataSource.getTagsByImageIds(imageIds);
      final metadataMap = await _dataSource.getMetadataByImageIds(imageIds);

      return files.where((file) {
        if (cancelToken.isCancelled) return false;

        final imageId = pathToIdMap[file.path];
        if (imageId == null) return false;

        final fileTags = (tagsMap[imageId] ?? [])
            .map(TagNormalizer.normalizeTagForMatch)
            .where((tag) => tag.isNotEmpty)
            .toSet();
        final metadataText = TagNormalizer.normalizeTagForMatch(
          metadataMap[imageId]?.fullPromptText ?? '',
        );

        return requiredTags.every(
          (tag) =>
              fileTags.contains(tag) ||
              _normalizedTextContainsTag(metadataText, tag),
        );
      }).toList();
    } catch (e, stack) {
      throw _filterFailure(
        'tags:${tags.join(",")}',
        'Failed to filter by tags',
        e,
        stack,
      );
    }
  }

  bool _hasDelimitedSearchQuery(String value) {
    return value.contains(',') || value.contains('，');
  }

  List<String> _parseDelimitedSearchSegments(String value) {
    return TagNormalizer.parseDelimitedSearchSegments(value);
  }

  bool _normalizedTextContainsTag(String normalizedText, String normalizedTag) {
    if (normalizedText.isEmpty || normalizedTag.isEmpty) return false;

    return ' $normalizedText '.contains(' $normalizedTag ');
  }

  /// 按日期范围过滤
  Future<List<File>> _filterByDateRange(
    List<File> files,
    FilterCriteria criteria,
    CancelToken cancelToken,
  ) async {
    if (files.isEmpty) return files;
    if (cancelToken.isCancelled) return [];

    final effectiveEndDate = criteria.dateEnd?.add(const Duration(days: 1));
    final matchingPaths = await ComputeGate().runCompute(
      _filterBatchByDate,
      _DateFilterParams(
        filePaths: files.map((file) => file.path).toList(),
        dateStart: criteria.dateStart,
        dateEnd: effectiveEndDate,
      ),
    );

    if (cancelToken.isCancelled) return [];

    return matchingPaths.map((path) => File(path)).toList();
  }

  /// 按相簿过滤（'favorites' 收藏相簿；其余为相簿 id，含子相簿成员）
  Future<List<File>> _filterByAlbum(
    List<File> files,
    String albumId,
    CancelToken cancelToken,
  ) async {
    try {
      if (albumId == 'favorites') {
        final records = await _dataSource.queryFavoriteImages(
          limit: max(1, files.length),
        );
        final favoriteKeys = {
          for (final record in records) galleryFilePathKey(record.filePath),
        };
        return files
            .where(
              (file) =>
                  !cancelToken.isCancelled &&
                  favoriteKeys.contains(galleryFilePathKey(file.path)),
            )
            .toList();
      }

      final memberPaths = await _dataSource.albums
          .getAlbumFilePathsWithDescendants(albumId);
      final memberKeys = {
        for (final path in memberPaths) galleryFilePathKey(path),
      };
      return files
          .where(
            (file) =>
                !cancelToken.isCancelled &&
                memberKeys.contains(galleryFilePathKey(file.path)),
          )
          .toList();
    } catch (e) {
      AppLogger.w('Failed to filter by album: $e', 'GalleryFilterService');
      return [];
    }
  }

  /// 按分类路径过滤
  ///
  /// 根据分类的文件夹路径过滤文件
  Future<List<File>> _filterByCategory(
    List<File> files,
    String categoryFolderPath,
    CancelToken cancelToken,
  ) async {
    try {
      // 规范化路径分隔符并转换为小写以便比较
      final normalizedCategoryPath = categoryFolderPath
          .replaceAll('\\', '/')
          .toLowerCase();

      return files.where((file) {
        if (cancelToken.isCancelled) return false;

        // 规范化文件路径
        final normalizedFilePath = file.path
            .replaceAll('\\', '/')
            .toLowerCase();

        // 检查文件路径是否包含分类文件夹路径
        // 使用 / 确保精确匹配文件夹名（如 "test_batch/" 不匹配 "test_batch_2/"）
        return normalizedFilePath.contains('$normalizedCategoryPath/') ||
            normalizedFilePath.endsWith('/$normalizedCategoryPath');
      }).toList();
    } catch (e) {
      AppLogger.w('Failed to filter by category: $e', 'GalleryFilterService');
      return files;
    }
  }

  /// 取消过滤操作
  void cancelFilter(String operationId) {
    final token = _activeFilters[operationId];
    if (token != null) {
      token.cancel();
      AppLogger.d('Filter cancelled: $operationId', 'GalleryFilterService');
    }
  }

  /// 取消所有过滤操作
  void cancelAllFilters() {
    for (final entry in _activeFilters.entries) {
      entry.value.cancel();
    }
    AppLogger.d('All filters cancelled', 'GalleryFilterService');
  }

  /// 清空所有过滤条件
  FilterCriteria clearAllFilters(FilterCriteria current) {
    return const FilterCriteria();
  }
}

/// 过滤条件在管线各阶段的分配结果
@immutable
class _FilterPlan {
  const _FilterPlan({
    required this.databaseCriteria,
    required this.delimitedSearchQuery,
    required this.applyLocalDateRange,
  });

  final FilterCriteria? databaseCriteria;
  final String? delimitedSearchQuery;
  final bool applyLocalDateRange;
}

/// 取消令牌
class CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// 过滤取消异常
class FilterCancelledException implements Exception {
  const FilterCancelledException();

  @override
  String toString() => 'Filter operation was cancelled';
}

/// 日期过滤参数
class _DateFilterParams {
  final List<String> filePaths;
  final DateTime? dateStart;
  final DateTime? dateEnd;

  _DateFilterParams({required this.filePaths, this.dateStart, this.dateEnd});
}

/// 在 isolate 中批量过滤日期
List<String> _filterBatchByDate(_DateFilterParams params) {
  final result = <String>[];

  for (final path in params.filePaths) {
    try {
      final file = File(path);
      if (!file.existsSync()) continue;

      final modifiedAt = file.lastModifiedSync();

      if (params.dateStart != null && modifiedAt.isBefore(params.dateStart!)) {
        continue;
      }
      if (params.dateEnd != null && modifiedAt.isAfter(params.dateEnd!)) {
        continue;
      }

      result.add(path);
    } catch (_) {
      // 忽略文件访问错误
    }
  }

  return result;
}
