import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/prompt/tag_group.dart';
import '../../models/prompt/tag_group_mapping.dart';
import '../../models/prompt/weighted_tag.dart';
import 'danbooru_api_service.dart';
import 'dtext_parser.dart';

part 'danbooru_tag_group_service.g.dart';

/// Danbooru Tag Group 服务
///
/// 负责从 Danbooru wiki_pages 获取 tag_group 数据
/// 替代原有的 DanbooruPoolService
class DanbooruTagGroupService {
  final DanbooruApiService _apiService;

  /// 缓存的 tag_group 数据
  final Map<String, TagGroup> _groupCache = {};

  /// 缓存的标签热度数据
  final Map<String, int> _postCountCache = {};

  /// 缓存有效期
  static const Duration _cacheValidity = Duration(hours: 24);

  /// 缓存时间戳
  DateTime? _cacheTimestamp;

  DanbooruTagGroupService(this._apiService);

  /// 获取指定 tag_group 页面
  ///
  /// [title] tag_group 标题 (如 "tag_group:hair_color")
  /// [fetchPostCounts] 是否获取标签热度
  Future<TagGroup?> getTagGroup(
    String title, {
    bool fetchPostCounts = false,
  }) async {
    // 检查缓存
    if (_isCacheValid() && _groupCache.containsKey(title)) {
      return _groupCache[title];
    }

    try {
      // 获取 wiki 页面
      final wikiData = await _apiService.getWikiPage(title);
      if (wikiData == null) {
        AppLogger.w('Wiki page not found: $title', 'TagGroup');
        return null;
      }

      // 解析页面内容
      final body = wikiData['body'] as String? ?? '';
      final parseResult = DTextParser.parse(body);

      // 构建 TagGroup
      var group = TagGroup(
        id: wikiData['id'] as int? ?? 0,
        title: title,
        displayName: TagGroup.titleToDisplayName(title),
        childGroupTitles: parseResult.childGroups,
        tags:
            parseResult.tags.map((name) => TagGroupEntry(name: name)).toList(),
        lastUpdated: DateTime.now(),
      );

      // 获取标签热度
      if (fetchPostCounts && group.tags.isNotEmpty) {
        group = await _enrichWithPostCounts(group);
      }

      // 缓存结果
      _groupCache[title] = group;
      _updateCacheTimestamp();

      AppLogger.d(
        'Loaded tag group: $title, ${group.tagCount} tags, '
            '${group.childGroupTitles.length} children',
        'TagGroup',
      );

      return group;
    } catch (e, stack) {
      AppLogger.e('Failed to get tag group: $title', e, stack, 'TagGroup');
      return null;
    }
  }

  /// 为 TagGroup 添加标签热度信息
  Future<TagGroup> _enrichWithPostCounts(TagGroup group) async {
    final tagNames = group.tags.map((t) => t.name).toList();

    // 检查缓存中已有的热度数据
    final uncachedTags = <String>[];
    for (final name in tagNames) {
      if (!_postCountCache.containsKey(name)) {
        uncachedTags.add(name);
      }
    }

    // 获取未缓存的标签热度
    if (uncachedTags.isNotEmpty) {
      final postCounts = await _apiService.batchGetTagPostCounts(uncachedTags);
      _postCountCache.addAll(postCounts);
    }

    // 更新标签的热度信息
    final enrichedTags = group.tags.map((tag) {
      final postCount = _postCountCache[tag.name] ?? 0;
      return tag.copyWith(
        postCount: postCount,
        hasPostCount: true,
      );
    }).toList();

    // 按热度排序
    enrichedTags.sort((a, b) => b.postCount.compareTo(a.postCount));

    return group.copyWith(tags: enrichedTags);
  }

  /// 同步指定 tag_group 的标签
  ///
  /// [groupTitle] tag_group 标题
  /// [minPostCount] 最小热度阈值
  /// [maxTags] 最大标签数
  /// [includeChildren] 是否包含子分组的标签
  /// [onProgress] 进度回调
  /// [maxConcurrency] 子分组并发获取数
  Future<TagGroup?> syncTagGroup({
    required String groupTitle,
    int minPostCount = 1000,
    int maxTags = 200,
    bool includeChildren = true,
    void Function(TagGroupSyncProgress)? onProgress,
    int maxConcurrency = 3,
  }) async {
    onProgress?.call(TagGroupSyncProgress.fetchingGroup(groupTitle, 0, 1));

    // 获取主分组
    final group = await getTagGroup(groupTitle, fetchPostCounts: true);
    if (group == null) {
      onProgress?.call(TagGroupSyncProgress.failed('无法获取分组: $groupTitle'));
      return null;
    }

    // 收集所有标签
    final allTags = <TagGroupEntry>[...group.tags];

    // 获取子分组的标签（并发）
    if (includeChildren && group.hasChildren) {
      final childTitles = group.childGroupTitles;
      final totalChildren = childTitles.length;
      var completedCount = 0;

      // 使用并发池获取子分组
      final childGroups = await _runConcurrent<String, TagGroup?>(
        items: childTitles,
        maxConcurrency: maxConcurrency,
        task: (childTitle) => getTagGroup(childTitle, fetchPostCounts: true),
        onItemComplete: (_, __) {
          completedCount++;
          onProgress?.call(
            TagGroupSyncProgress.fetchingGroup(
              groupTitle,
              completedCount,
              totalChildren + 1,
            ),
          );
        },
      );

      // 合并子分组标签
      final existingNames = allTags.map((t) => t.name).toSet();
      for (final childGroup in childGroups) {
        if (childGroup != null) {
          for (final tag in childGroup.tags) {
            if (!existingNames.contains(tag.name)) {
              allTags.add(tag);
              existingNames.add(tag.name);
            }
          }
        }
      }
    }

    onProgress?.call(
      TagGroupSyncProgress.filtering(
        allTags.length,
        allTags.where((t) => t.postCount >= minPostCount).length,
      ),
    );

    // 按热度筛选和排序
    final filteredTags = allTags
        .where((t) => t.postCount >= minPostCount)
        .toList()
      ..sort((a, b) => b.postCount.compareTo(a.postCount));

    // 限制数量
    final finalTags = filteredTags.take(maxTags).toList();

    onProgress?.call(
      TagGroupSyncProgress.completed(
        allTags.length,
        finalTags.length,
      ),
    );

    return group.copyWith(
      tags: finalTags,
      originalTagCount: allTags.length,
      lastUpdated: DateTime.now(),
    );
  }

  /// 批量同步多个 tag_group 映射
  ///
  /// [mappings] 映射配置列表
  /// [minPostCount] 全局最小热度阈值
  /// [maxTagsPerGroup] 每个分组最大标签数
  /// [onProgress] 进度回调
  /// [maxConcurrency] 最大并发数
  Future<TagGroupSyncResult> syncTagGroupMappings({
    required List<TagGroupMapping> mappings,
    int minPostCount = 1000,
    int maxTagsPerGroup = 200,
    void Function(TagGroupSyncProgress)? onProgress,
    int maxConcurrency = 2,
  }) async {
    if (mappings.isEmpty) {
      return const TagGroupSyncResult();
    }

    final enabledMappings = mappings.where((m) => m.enabled).toList();
    if (enabledMappings.isEmpty) {
      return const TagGroupSyncResult();
    }

    onProgress?.call(TagGroupSyncProgress.initial());

    final tagsByCategory = <String, List<TagGroupEntry>>{};
    final tagCountByGroup = <String, int>{};
    final originalTagCountByGroup = <String, int>{};
    var totalFetched = 0;
    var totalFiltered = 0;
    var completedCount = 0;

    // 并发处理映射
    final syncResults = await _runConcurrent<TagGroupMapping, TagGroup?>(
      items: enabledMappings,
      maxConcurrency: maxConcurrency,
      task: (mapping) async {
        final effectiveMinPostCount =
            mapping.customMinPostCount ?? minPostCount;
        try {
          return await syncTagGroup(
            groupTitle: mapping.groupTitle,
            minPostCount: effectiveMinPostCount,
            maxTags: maxTagsPerGroup,
            includeChildren: mapping.includeChildren,
            maxConcurrency: 3, // 子分组并发
          );
        } catch (e) {
          AppLogger.w(
            'Failed to sync tag group: ${mapping.groupTitle}',
            'TagGroup',
          );
          return null;
        }
      },
      onItemComplete: (mapping, _) {
        completedCount++;
        onProgress?.call(
          TagGroupSyncProgress.fetchingGroup(
            mapping.displayName,
            completedCount,
            enabledMappings.length,
          ),
        );
      },
    );

    // 汇总结果
    for (var i = 0; i < enabledMappings.length; i++) {
      final mapping = enabledMappings[i];
      final group = syncResults.length > i ? syncResults[i] : null;

      if (group != null && group.hasTags) {
        final categoryName = mapping.targetCategory.name;

        // 合并到目标分类
        final existingTags = tagsByCategory[categoryName] ?? [];
        final existingNames = existingTags.map((t) => t.name).toSet();

        for (final tag in group.tags) {
          if (!existingNames.contains(tag.name)) {
            existingTags.add(tag);
            existingNames.add(tag.name);
          }
        }

        tagsByCategory[categoryName] = existingTags;
        tagCountByGroup[mapping.groupTitle] = group.tagCount;
        originalTagCountByGroup[mapping.groupTitle] = group.originalTagCount;
        totalFetched += group.originalTagCount;
        totalFiltered += group.tags.length;
      }
    }

    onProgress
        ?.call(TagGroupSyncProgress.completed(totalFetched, totalFiltered));

    return TagGroupSyncResult(
      tagsByCategory: tagsByCategory,
      tagCountByGroup: tagCountByGroup,
      originalTagCountByGroup: originalTagCountByGroup,
      totalFetchedTags: totalFetched,
      totalFilteredTags: totalFiltered,
    );
  }

  /// 将 TagGroupEntry 列表转换为 WeightedTag 列表
  ///
  /// [entries] TagGroupEntry 列表
  /// [source] 标签来源
  List<WeightedTag> entriesToWeightedTags(
    List<TagGroupEntry> entries, {
    TagSource source = TagSource.danbooru,
  }) {
    return entries.map((entry) {
      // 根据热度计算权重 (1-10)
      final weight = _calculateWeight(entry.postCount);
      return WeightedTag(
        tag: entry.displayName,
        weight: weight,
        source: source,
      );
    }).toList();
  }

  /// 根据帖子数量计算权重
  ///
  /// 使用对数刻度，将热度映射到 1-10 的权重范围
  int _calculateWeight(int postCount) {
    if (postCount <= 0) return 1;
    if (postCount < 1000) return 1;
    if (postCount < 5000) return 2;
    if (postCount < 10000) return 3;
    if (postCount < 50000) return 4;
    if (postCount < 100000) return 5;
    if (postCount < 500000) return 6;
    if (postCount < 1000000) return 7;
    if (postCount < 2000000) return 8;
    if (postCount < 5000000) return 9;
    return 10;
  }

  /// 搜索可用的 tag_group 页面
  ///
  /// [query] 搜索关键词（可选）
  /// [limit] 最大返回数量
  Future<List<TagGroup>> searchTagGroups({
    String? query,
    int limit = 50,
  }) async {
    try {
      final pattern = query != null && query.isNotEmpty
          ? 'tag_group:*$query*'
          : 'tag_group:*';

      final wikiPages = await _apiService.searchWikiPages(
        titlePattern: pattern,
        limit: limit,
      );

      final groups = <TagGroup>[];
      for (final page in wikiPages) {
        final title = page['title'] as String? ?? '';
        if (title.startsWith('tag_group:')) {
          final body = page['body'] as String? ?? '';
          final parseResult = DTextParser.parse(body);

          groups.add(
            TagGroup(
              id: page['id'] as int? ?? 0,
              title: title,
              displayName: TagGroup.titleToDisplayName(title),
              childGroupTitles: parseResult.childGroups,
              tags: parseResult.tags
                  .map((name) => TagGroupEntry(name: name))
                  .toList(),
            ),
          );
        }
      }

      return groups;
    } catch (e, stack) {
      AppLogger.e('Failed to search tag groups', e, stack, 'TagGroup');
      return [];
    }
  }

  /// 预设的常用 tag_group 及其子分组
  /// 当无法从 Danbooru 解析时使用
  /// 注意：这些都是经过 API 验证的有效 wiki 页面
  static const Map<String, List<String>> _presetTagGroupHierarchy = {
    // 外貌特征
    'tag_group:hair_color': [],
    'tag_group:eye_color': [],
    'tag_group:hair_styles': [],
    'tag_group:skin_color': [],
    // 姿势与动作
    'tag_group:posture': [],
    'tag_group:gestures': [],
    // 服饰与配件
    'tag_group:attire': [
      'tag_group:headwear',
      'tag_group:dress',
      'tag_group:legwear',
      'tag_group:eyewear',
      'tag_group:footwear',
    ],
    'tag_group:accessories': [
      'tag_group:headwear',
      'tag_group:eyewear',
      'tag_group:handwear',
      'tag_group:legwear',
      'tag_group:footwear',
      'tag_group:piercings',
    ],
    'tag_group:headwear': [],
    'tag_group:eyewear': [],
    'tag_group:legwear': [],
    'tag_group:footwear': [],
    // 背景与构图
    'tag_group:backgrounds': [],
    'tag_group:image_composition': [],
  };

  /// 顶级 tag_group 列表（用于树状浏览）
  /// 这些都是经过 API 验证的有效 wiki 页面
  static const List<String> _topLevelGroups = [
    'tag_group:hair_color',
    'tag_group:eye_color',
    'tag_group:hair_styles',
    'tag_group:skin_color',
    'tag_group:posture',
    'tag_group:gestures',
    'tag_group:attire',
    'tag_group:accessories',
    'tag_group:backgrounds',
    'tag_group:image_composition',
  ];

  /// 获取顶级 tag_group 列表（用于浏览器）
  Future<List<TagGroup>> getTopLevelTagGroups() async {
    // 尝试获取主 tag_groups 页面
    try {
      final mainGroup = await getTagGroup('tag_groups');
      if (mainGroup != null && mainGroup.hasChildren) {
        final groups = <TagGroup>[];
        for (final childTitle in mainGroup.childGroupTitles) {
          final child = await getTagGroup(childTitle);
          if (child != null) {
            groups.add(child);
          }
        }
        if (groups.isNotEmpty) {
          return groups;
        }
      }
    } catch (e) {
      AppLogger.w('Failed to get main tag_groups page: $e', 'TagGroup');
    }

    // 尝试搜索 tag_group:* 页面
    try {
      final searchResults = await searchTagGroups(limit: 100);
      if (searchResults.isNotEmpty) {
        return searchResults;
      }
    } catch (e) {
      AppLogger.w('Failed to search tag groups: $e', 'TagGroup');
    }

    // 使用预设列表作为后备
    AppLogger.d('Using preset tag group list as fallback', 'TagGroup');
    return _getPresetTagGroups();
  }

  /// 获取预设的 tag groups（带层级信息）
  Future<List<TagGroup>> _getPresetTagGroups() async {
    final groups = <TagGroup>[];

    for (final title in _topLevelGroups) {
      // 尝试从缓存或 API 获取
      var group = await getTagGroup(title);

      if (group != null) {
        // 如果 API 返回的分组没有子分组信息，使用预设的
        if (!group.hasChildren && _presetTagGroupHierarchy.containsKey(title)) {
          final presetChildren = _presetTagGroupHierarchy[title]!;
          if (presetChildren.isNotEmpty) {
            group = group.copyWith(childGroupTitles: presetChildren);
          }
        }
        groups.add(group);
      } else {
        // 创建带有预设子分组的占位符
        final childTitles = _presetTagGroupHierarchy[title] ?? [];
        groups.add(
          TagGroup(
            id: 0,
            title: title,
            displayName: TagGroup.titleToDisplayName(title),
            childGroupTitles: childTitles,
            tags: [],
          ),
        );
      }
    }
    return groups;
  }

  /// 检查缓存是否有效
  bool _isCacheValid() {
    if (_cacheTimestamp == null) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheValidity;
  }

  /// 更新缓存时间戳
  void _updateCacheTimestamp() {
    _cacheTimestamp = DateTime.now();
  }

  /// 清除缓存
  void clearCache() {
    _groupCache.clear();
    _postCountCache.clear();
    _cacheTimestamp = null;
  }

  /// 并发执行任务的辅助方法
  ///
  /// [items] 要处理的项目列表
  /// [maxConcurrency] 最大并发数
  /// [task] 对每个项目执行的异步任务
  /// [onItemComplete] 每个项目完成时的回调
  Future<List<R>> _runConcurrent<T, R>({
    required List<T> items,
    required int maxConcurrency,
    required Future<R> Function(T) task,
    void Function(T item, R result)? onItemComplete,
  }) async {
    if (items.isEmpty) return [];

    final results = List<R?>.filled(items.length, null);
    final activeTasks = <int, Future<void>>{};
    var nextIndex = 0;
    final completer = Completer<void>();
    var completedCount = 0;

    void startNextTask() {
      while (activeTasks.length < maxConcurrency && nextIndex < items.length) {
        final currentIndex = nextIndex++;
        final item = items[currentIndex];

        final future = task(item).then((result) {
          results[currentIndex] = result;
          onItemComplete?.call(item, result);
          completedCount++;
          activeTasks.remove(currentIndex);

          if (completedCount == items.length) {
            completer.complete();
          } else {
            startNextTask();
          }
        }).catchError((e) {
          // 记录错误但继续处理其他任务
          AppLogger.w('Concurrent task failed: $e', 'TagGroup');
          completedCount++;
          activeTasks.remove(currentIndex);

          if (completedCount == items.length) {
            completer.complete();
          } else {
            startNextTask();
          }
        });

        activeTasks[currentIndex] = future;
      }
    }

    startNextTask();

    if (items.isNotEmpty) {
      await completer.future;
    }

    return results.whereType<R>().toList();
  }
}

/// Provider
@Riverpod(keepAlive: true)
DanbooruTagGroupService danbooruTagGroupService(
  DanbooruTagGroupServiceRef ref,
) {
  final apiService = ref.watch(danbooruApiServiceProvider);
  return DanbooruTagGroupService(apiService);
}
