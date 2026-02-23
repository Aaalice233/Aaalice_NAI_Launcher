import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/utils/app_logger.dart';

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
    bool clearDateStart = false,
    bool clearDateEnd = false,
    bool clearFilterModel = false,
    bool clearFilterSampler = false,
    bool clearFilterMinSteps = false,
    bool clearFilterMaxSteps = false,
    bool clearFilterMinCfg = false,
    bool clearFilterMaxCfg = false,
    bool clearFilterResolution = false,
  }) {
    return FilterCriteria(
      searchQuery: searchQuery ?? this.searchQuery,
      dateStart: clearDateStart ? null : (dateStart ?? this.dateStart),
      dateEnd: clearDateEnd ? null : (dateEnd ?? this.dateEnd),
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      selectedTags: selectedTags ?? this.selectedTags,
      filterModel: clearFilterModel ? null : (filterModel ?? this.filterModel),
      filterSampler: clearFilterSampler ? null : (filterSampler ?? this.filterSampler),
      filterMinSteps: clearFilterMinSteps ? null : (filterMinSteps ?? this.filterMinSteps),
      filterMaxSteps: clearFilterMaxSteps ? null : (filterMaxSteps ?? this.filterMaxSteps),
      filterMinCfg: clearFilterMinCfg ? null : (filterMinCfg ?? this.filterMinCfg),
      filterMaxCfg: clearFilterMaxCfg ? null : (filterMaxCfg ?? this.filterMaxCfg),
      filterResolution: clearFilterResolution ? null : (filterResolution ?? this.filterResolution),
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
      filterResolution != null;

  bool get hasMetadataFilters =>
      filterModel != null ||
      filterSampler != null ||
      filterResolution != null ||
      filterMinSteps != null ||
      filterMaxSteps != null ||
      filterMinCfg != null ||
      filterMaxCfg != null;
}

/// 画廊过滤服务
///
/// 将过滤逻辑从 Notifier 中提取出来，使代码更清晰可测试
class GalleryFilterService {
  final GalleryDataSource _dataSource;

  GalleryFilterService(this._dataSource);

  /// 应用过滤条件
  ///
  /// 返回过滤后的文件列表
  Future<List<File>> applyFilters(
    List<File> allFiles,
    FilterCriteria criteria,
  ) async {
    final query = criteria.searchQuery.toLowerCase().trim();

    // 无过滤
    if (!criteria.hasFilters) {
      return allFiles;
    }

    // 有搜索关键词：使用数据库搜索
    if (query.isNotEmpty) {
      return _searchInDatabase(allFiles, criteria, query);
    }

    // 本地过滤
    var filtered = _filterByName(allFiles, query);

    // 日期过滤
    if (criteria.dateStart != null || criteria.dateEnd != null) {
      filtered = await _filterByDateRange(filtered, criteria);
    }

    // 收藏过滤
    if (criteria.showFavoritesOnly) {
      filtered = await _filterByFavorites(filtered);
    }

    return filtered;
  }

  /// 在数据库中搜索
  Future<List<File>> _searchInDatabase(
    List<File> allFiles,
    FilterCriteria criteria,
    String query,
  ) async {
    try {
      final imageIds = await _dataSource.advancedSearch(
        textQuery: query,
        favoritesOnly: criteria.showFavoritesOnly,
        dateStart: criteria.dateStart,
        dateEnd: criteria.dateEnd,
        limit: 10000,
      );

      // 获取图片记录并转换为文件列表
      final images = await _dataSource.getImagesByIds(imageIds);
      return images.map((img) => File(img.filePath)).toList();
    } catch (e) {
      AppLogger.w('Search failed: $e', 'GalleryFilterService');
      // 回退到本地过滤
      return _filterByName(allFiles, query);
    }
  }

  /// 按文件名过滤
  List<File> _filterByName(List<File> files, String query) {
    if (query.isEmpty) return files;

    return files.where((file) {
      final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  /// 按日期范围过滤
  Future<List<File>> _filterByDateRange(
    List<File> files,
    FilterCriteria criteria,
  ) async {
    const batchSize = 50;
    final effectiveEndDate = criteria.dateEnd?.add(const Duration(days: 1));
    final result = <File>[];

    for (var i = 0; i < files.length; i += batchSize) {
      final batch = files.sublist(i, min(i + batchSize, files.length));
      final batchStats = await Future.wait(
        batch.map((file) async {
          try {
            return (file: file, modified: (await file.stat()).modified);
          } catch (_) {
            return null;
          }
        }),
      );

      for (final stat in batchStats.whereType<({File file, DateTime modified})>()) {
        final modifiedAt = stat.modified;
        if (criteria.dateStart != null && modifiedAt.isBefore(criteria.dateStart!)) {
          continue;
        }
        if (effectiveEndDate != null && modifiedAt.isAfter(effectiveEndDate)) {
          continue;
        }
        result.add(stat.file);
      }
    }

    return result;
  }

  /// 按收藏状态过滤
  Future<List<File>> _filterByFavorites(List<File> files) async {
    try {
      final favoriteImageIds = await _dataSource.getFavoriteImageIds();
      final favoriteImages = await _dataSource.getImagesByIds(favoriteImageIds);
      final favoritePaths = favoriteImages.map((img) => img.filePath).toSet();
      return files.where((file) => favoritePaths.contains(file.path)).toList();
    } catch (e) {
      AppLogger.w('Failed to filter favorites: $e', 'GalleryFilterService');
      return files;
    }
  }

  /// 清空所有过滤条件
  FilterCriteria clearAllFilters(FilterCriteria current) {
    return const FilterCriteria();
  }
}
