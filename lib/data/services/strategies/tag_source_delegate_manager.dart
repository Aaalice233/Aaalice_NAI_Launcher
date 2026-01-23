import '../../datasources/local/pool_cache_service.dart';
import '../../datasources/local/tag_group_cache_service.dart';
import '../../models/prompt/random_category.dart';
import '../../models/prompt/random_tag_group.dart';
import '../../models/prompt/weighted_tag.dart';
import 'tag_source_delegate.dart';

/// 标签源策略管理器
///
/// 统一管理和调度各种标签来源策略
class TagSourceDelegateManager {
  final TagGroupCacheService _tagGroupCacheService;
  final PoolCacheService _poolCacheService;

  late final List<TagSourceDelegate> _delegates;

  TagSourceDelegateManager(
    this._tagGroupCacheService,
    this._poolCacheService,
  ) {
    _delegates = [
      CustomSourceDelegate(),
      TagGroupSourceDelegate(_tagGroupCacheService),
      PoolSourceDelegate(_poolCacheService),
      BuiltinSourceDelegate(),
    ];
  }

  /// 获取适合的策略
  TagSourceDelegate getDelegate(RandomTagGroup group) {
    for (final delegate in _delegates) {
      if (delegate.supports(group)) {
        return delegate;
      }
    }
    // 默认返回自定义策略
    return _delegates.first;
  }

  /// 获取所有策略
  List<TagSourceDelegate> getAllDelegates() {
    return List.unmodifiable(_delegates);
  }

  /// 根据类型获取策略
  TagSourceDelegate? getDelegateByType(TagSourceType type) {
    for (final delegate in _delegates) {
      if (delegate.sourceTypeName == _getTypeDisplayName(type)) {
        return delegate;
      }
    }
    return null;
  }

  String _getTypeDisplayName(TagSourceType type) {
    return switch (type) {
      TagSourceType.custom => '自定义',
      TagSourceType.tagGroup => 'Danbooru Tag Group',
      TagSourceType.pool => 'Danbooru Pool',
      TagSourceType.builtin => '内置词库',
    };
  }

  /// 获取标签
  Future<List<WeightedTag>> getTags(
    RandomTagGroup group,
    RandomCategory category,
  ) async {
    final delegate = getDelegate(group);
    return delegate.getTagsForGroup(group, category);
  }
}

/// 简单的自定义策略实现
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
    if (group.isNested) {
      return _getNestedTags(group);
    }
    return group.tags;
  }

  Future<List<WeightedTag>> _getNestedTags(RandomTagGroup group) async {
    final allTags = <WeightedTag>[];
    for (final child in group.children) {
      if (!child.enabled) continue;
      if (child.isNested) {
        allTags.addAll(await _getNestedTags(child));
      } else {
        allTags.addAll(child.tags);
      }
    }
    return allTags;
  }
}

/// Tag Group 策略实现
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
    if (sourceId == null || sourceId.isEmpty) return group.tags;

    final tagGroup = await _cacheService.getTagGroup(sourceId);
    if (tagGroup == null) return group.tags;

    return tagGroup.tags.map((entry) {
      final weight = _calculateWeight(entry.postCount);
      return WeightedTag(
        tag: entry.name.replaceAll('_', ' '),
        weight: weight,
      );
    }).toList();
  }

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

/// Pool 策略实现
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
    if (sourceId == null || sourceId.isEmpty) return [];

    final poolId = int.tryParse(sourceId);
    if (poolId == null) return [];

    final poolEntry = await _cacheService.getPool(poolId);
    if (poolEntry == null || poolEntry.posts.isEmpty) return [];

    final allTags = <String>{};
    for (final post in poolEntry.posts) {
      final tags = post.getTagsForOutput(group.poolOutputConfig);
      allTags.addAll(tags);
    }

    return allTags.map((tag) => WeightedTag(tag: tag, weight: 5)).toList();
  }
}

/// 内置词库策略实现
class BuiltinSourceDelegate implements TagSourceDelegate {
  BuiltinSourceDelegate();

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
    // 根据 sourceId 获取对应的分类
    // 这里需要根据实际的 TagSubCategory 实现
    return [];
  }
}
