import '../../datasources/local/pool_cache_service.dart';
import '../../datasources/local/tag_group_cache_service.dart';
import '../../models/prompt/random_category.dart';
import '../../models/prompt/random_tag_group.dart';
import '../../models/prompt/weighted_tag.dart';
import '../../services/tag_library_service.dart';
import 'tag_source_delegate.dart';

/// 自定义标签来源策略
class CustomSourceDelegate implements TagSourceDelegate {
  @override
  String get sourceTypeName => '自定义';

  @override
  bool supports(RandomTagGroup group) {
    return group.sourceType == TagGroupSourceType.custom;
  }

  @override
  Future<List<WeightedTag>> getTagsForGroup(
    RandomTagGroup group,
    RandomCategory category,
  ) async {
    // 自定义类型：直接返回内嵌标签
    // 考虑嵌套结构
    if (group.isNested) {
      return _getNestedTags(group, category);
    }

    return group.tags;
  }

  /// 递归获取嵌套词组的标签
  Future<List<WeightedTag>> _getNestedTags(
    RandomTagGroup group,
    RandomCategory category,
  ) async {
    final allTags = <WeightedTag>[];

    for (final child in group.children) {
      if (!child.enabled) continue;

      if (child.isNested) {
        allTags.addAll(await _getNestedTags(child, category));
      } else {
        allTags.addAll(child.tags);
      }
    }

    return allTags;
  }
}

/// Danbooru Tag Group 来源策略
class TagGroupSourceDelegate implements TagSourceDelegate {
  final TagGroupCacheService _cacheService;

  TagGroupSourceDelegate(this._cacheService);

  @override
  String get sourceTypeName => 'Danbooru Tag Group';

  @override
  bool supports(RandomTagGroup group) {
    return group.sourceType == TagGroupSourceType.tagGroup;
  }

  @override
  Future<List<WeightedTag>> getTagsForGroup(
    RandomTagGroup group,
    RandomCategory category,
  ) async {
    final sourceId = group.sourceId;
    if (sourceId == null || sourceId.isEmpty) {
      return group.tags; // Fallback
    }

    final tagGroup = await _cacheService.getTagGroup(sourceId);
    if (tagGroup == null) {
      return group.tags; // Fallback
    }

    return _convertToWeightedTags(tagGroup.tags);
  }

  /// 将 TagGroupEntry 列表转换为 WeightedTag 列表
  List<WeightedTag> _convertToWeightedTags(List<dynamic> entries) {
    return entries.map((entry) {
      // 假设 entry 有 name 和 postCount 字段
      final name = entry.name?.replaceAll('_', ' ') ?? '';
      final postCount = entry.postCount ?? 0;
      final weight = _calculateWeight(postCount);

      return WeightedTag(
        tag: name,
        weight: weight,
      );
    }).toList();
  }

  /// 根据帖子数量计算权重 (1-10)
  int _calculateWeight(int postCount) {
    if (postCount <= 0) return 1;
    if (postCount < 100) return 1;
    if (postCount < 1000) return 2;
    if (postCount < 5000) return 3;
    if (postCount < 10000) return 4;
    if (postCount < 50000) return 5;
    if (postCount < 100000) return 6;
    if (postCount < 500000) return 7;
    if (postCount < 1000000) return 8;
    if (postCount < 5000000) return 9;
    return 10;
  }
}

/// Danbooru Pool 来源策略
class PoolSourceDelegate implements TagSourceDelegate {
  final PoolCacheService _cacheService;

  PoolSourceDelegate(this._cacheService);

  @override
  String get sourceTypeName => 'Danbooru Pool';

  @override
  bool supports(RandomTagGroup group) {
    return group.sourceType == TagGroupSourceType.pool;
  }

  @override
  Future<List<WeightedTag>> getTagsForGroup(
    RandomTagGroup group,
    RandomCategory category,
  ) async {
    final sourceId = group.sourceId;
    if (sourceId == null || sourceId.isEmpty) {
      return [];
    }

    final poolId = int.tryParse(sourceId);
    if (poolId == null) {
      return [];
    }

    final poolEntry = await _cacheService.getPool(poolId);
    if (poolEntry == null || poolEntry.posts.isEmpty) {
      return [];
    }

    // 从帖子中提取标签
    final allTags = <String>[];
    final outputConfig = group.poolOutputConfig;

    for (final post in poolEntry.posts) {
      final tags = post.getTagsForOutput(outputConfig);
      allTags.addAll(tags);
    }

    // 去重并转换为 WeightedTag
    final uniqueTags = allTags.toSet().toList();
    return uniqueTags.map((tag) {
      return WeightedTag(tag: tag, weight: 5); // Pool 标签默认权重 5
    }).toList();
  }
}

/// 内置词库来源策略
class BuiltinSourceDelegate implements TagSourceDelegate {
  final TagLibraryService _libraryService;

  BuiltinSourceDelegate(this._libraryService);

  @override
  String get sourceTypeName => '内置词库';

  @override
  bool supports(RandomTagGroup group) {
    return group.sourceType == TagGroupSourceType.builtin;
  }

  @override
  Future<List<WeightedTag>> getTagsForGroup(
    RandomTagGroup group,
    RandomCategory category,
  ) async {
    final sourceId = group.sourceId;
    if (sourceId == null || sourceId.isEmpty) {
      return [];
    }

    final library = await _libraryService.getAvailableLibrary();

    // 根据 sourceId 获取对应的 TagSubCategory
    try {
      // 假设 sourceId 对应 TagSubCategory 的 name
      final subCategory = _getSubCategory(sourceId);
      if (subCategory == null) return [];

      final tags = library.getCategory(subCategory);
      return tags
          .where((t) => !t.isDanbooruSupplement)
          .map((t) => WeightedTag(
                tag: t.tag,
                weight: t.weight,
              ),)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 获取 TagSubCategory
  dynamic _getSubCategory(String sourceId) {
    // 这里需要根据实际的 TagSubCategory 枚举实现
    // 简化的实现
    return null;
  }
}
