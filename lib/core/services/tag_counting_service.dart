import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_logger.dart';
import '../../data/models/prompt/random_category.dart';
import '../../data/models/prompt/tag_group_mapping.dart';
import '../../data/models/prompt/tag_group_preset_cache.dart';
import '../../data/datasources/local/tag_group_cache_service.dart';

part 'tag_counting_service.g.dart';

/// 标签计数服务
/// 负责管理和计算标签组映射的标签数量
///
/// 功能包括：
/// - 计算过滤后的标签数量
/// - 聚合多个映射的标签总数
/// - 处理分类启用状态
/// - 提供计数缓存和回退逻辑
class TagCountingService {
  /// 标签组缓存服务
  final TagGroupCacheService _cacheService;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 实时过滤的标签数量缓存（groupTitle -> count）
  final Map<String, int> _filteredTagCountsCache = {};

  TagCountingService(this._cacheService);

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 实时过滤的标签数量缓存
  Map<String, int> get filteredTagCounts => Map.unmodifiable(_filteredTagCountsCache);

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.i('Initializing TagCountingService...', 'TagCounting');

      // 确保缓存服务已初始化
      if (!_cacheService.isInitialized) {
        await _cacheService.init();
      }

      _isInitialized = true;
      AppLogger.i('TagCountingService initialized', 'TagCounting');
    } catch (e, stack) {
      AppLogger.e('Failed to initialize TagCountingService', e, stack, 'TagCounting');
      rethrow;
    }
  }

  /// 更新实时过滤的标签数量
  ///
  /// [mappings] 标签组映射列表
  /// [minPostCount] 最小帖子数阈值（0 表示不应用额外过滤）
  /// [includeChildren] 是否包含子组的标签
  Future<void> updateFilteredCounts(
    List<TagGroupMapping> mappings, {
    int minPostCount = 0,
    bool includeChildren = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final enabledMappings = mappings.where((m) => m.enabled).toList();
      if (enabledMappings.isEmpty) {
        _filteredTagCountsCache.clear();
        AppLogger.d('No enabled mappings, cleared filtered counts', 'TagCounting');
        return;
      }

      final groupTitles = enabledMappings.map((m) => m.groupTitle).toList();

      // 使用缓存服务获取过滤后的标签数量
      final counts = await _cacheService.getFilteredTagCountsAsync(
        groupTitles,
        minPostCount,
        includeChildren: includeChildren,
      );

      _filteredTagCountsCache.clear();
      _filteredTagCountsCache.addAll(counts);

      final total = counts.values.fold(0, (sum, c) => sum + c);
      AppLogger.d(
        'Updated filtered counts: ${counts.length} groups, total=$total',
        'TagCounting',
      );
    } catch (e, stack) {
      AppLogger.e('Failed to update filtered counts', e, stack, 'TagCounting');
      rethrow;
    }
  }

  /// 获取指定映射的标签数量
  ///
  /// 优先使用实时过滤数量，其次使用已同步数量，最后使用预缓存数量
  ///
  /// [mapping] 标签组映射
  /// [categories] 分类列表（用于检查分类是否启用）
  int getTagCountForMapping(
    TagGroupMapping mapping,
    List<RandomCategory> categories,
  ) {
    // 检查目标分类是否启用
    final randomCategory = categories.cast<RandomCategory?>().firstWhere(
          (c) => c?.key == mapping.targetCategory.name,
          orElse: () => null,
        );
    final categoryEnabled = randomCategory?.enabled ?? true;

    if (!categoryEnabled) {
      return 0;
    }

    // 优先使用实时过滤数量
    final filteredCount = _filteredTagCountsCache[mapping.groupTitle];
    if (filteredCount != null) {
      return filteredCount;
    }

    // 其次使用已同步数量
    if (mapping.lastSyncedTagCount > 0) {
      return mapping.lastSyncedTagCount;
    }

    // 最后使用预缓存数量
    final cachedCount = TagGroupPresetCache.getCount(mapping.groupTitle);
    return cachedCount ?? 0;
  }

  /// 计算多个映射的总标签数量
  ///
  /// [mappings] 标签组映射列表
  /// [categories] 分类列表（用于检查分类是否启用）
  int calculateTotalTagCount(
    List<TagGroupMapping> mappings,
    List<RandomCategory> categories,
  ) {
    int totalTagCount = 0;

    for (final mapping in mappings) {
      if (!mapping.enabled) continue;

      final count = getTagCountForMapping(mapping, categories);
      totalTagCount += count;
    }

    return totalTagCount;
  }

  /// 计算启用的映射数量
  ///
  /// [mappings] 标签组映射列表
  int calculateEnabledMappingCount(List<TagGroupMapping> mappings) {
    return mappings.where((m) => m.enabled).length;
  }

  /// 获取实时过滤的标签数量
  ///
  /// [groupTitle] 标签组标题
  int? getFilteredTagCount(String groupTitle) {
    return _filteredTagCountsCache[groupTitle];
  }

  /// 获取所有实时过滤的标签数量总和
  int get totalFilteredTagCount {
    return _filteredTagCountsCache.values.fold(0, (sum, c) => sum + c);
  }

  /// 清除缓存
  void clearCache() {
    _filteredTagCountsCache.clear();
    AppLogger.d('Cleared filtered tag counts cache', 'TagCounting');
  }

  /// 重置服务状态
  Future<void> reset() async {
    clearCache();
    _isInitialized = false;
    AppLogger.i('TagCountingService reset', 'TagCounting');
  }
}

/// TagCountingService Provider
@Riverpod(keepAlive: true)
TagCountingService tagCountingService(Ref ref) {
  final cacheService = ref.watch(tagGroupCacheServiceProvider);
  return TagCountingService(cacheService);
}
