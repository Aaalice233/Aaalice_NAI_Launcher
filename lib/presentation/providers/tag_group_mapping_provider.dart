import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/remote/danbooru_tag_group_service.dart';
import '../../data/models/prompt/default_tag_group_mappings.dart';
import '../../data/models/prompt/tag_category.dart';
import '../../data/models/prompt/tag_group.dart';
import '../../data/models/prompt/tag_group_mapping.dart';
import '../../data/models/prompt/tag_group_sync_config.dart';
import '../../data/models/prompt/weighted_tag.dart';
import '../../data/services/tag_library_service.dart';
import 'tag_library_provider.dart';

part 'tag_group_mapping_provider.g.dart';

/// Tag Group 映射状态
class TagGroupMappingState {
  final TagGroupSyncConfig config;
  final Map<String, TagGroup> cachedGroups;
  final bool isLoading;
  final bool isSyncing;
  final TagGroupSyncProgress? syncProgress;
  final String? error;

  const TagGroupMappingState({
    this.config = const TagGroupSyncConfig(),
    this.cachedGroups = const {},
    this.isLoading = false,
    this.isSyncing = false,
    this.syncProgress,
    this.error,
  });

  TagGroupMappingState copyWith({
    TagGroupSyncConfig? config,
    Map<String, TagGroup>? cachedGroups,
    bool? isLoading,
    bool? isSyncing,
    TagGroupSyncProgress? syncProgress,
    String? error,
  }) {
    return TagGroupMappingState(
      config: config ?? this.config,
      cachedGroups: cachedGroups ?? this.cachedGroups,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
      error: error,
    );
  }
}

/// Tag Group 映射状态管理
@Riverpod(keepAlive: true)
class TagGroupMappingNotifier extends _$TagGroupMappingNotifier {
  TagLibraryService get _libraryService => ref.read(tagLibraryServiceProvider);
  DanbooruTagGroupService get _tagGroupService =>
      ref.read(danbooruTagGroupServiceProvider);

  @override
  TagGroupMappingState build() {
    _loadConfig();
    return const TagGroupMappingState(isLoading: true);
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final config = await _libraryService.loadTagGroupSyncConfig();
      state = state.copyWith(
        config: config,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.e('Failed to load tag group mapping config: $e', 'TagGroupMapping');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 设置是否启用 Tag Group 同步
  Future<void> setEnabled(bool enabled) async {
    final newConfig = state.config.copyWith(enabled: enabled);
    await _saveConfig(newConfig);
  }

  /// 设置最小热度阈值
  Future<void> setMinPostCount(int count) async {
    final newConfig = state.config.copyWith(minPostCount: count);
    await _saveConfig(newConfig);
  }

  /// 设置每分组最大标签数
  Future<void> setMaxTagsPerGroup(int count) async {
    final newConfig = state.config.copyWith(maxTagsPerGroup: count);
    await _saveConfig(newConfig);
  }

  /// 添加 Tag Group 映射
  /// [estimatedTagCount] 可选的预估标签数量，如果传入则直接使用，避免 API 请求
  Future<void> addMapping({
    required String groupTitle,
    required String displayName,
    required TagSubCategory targetCategory,
    bool includeChildren = true,
    int? customMinPostCount,
    int? estimatedTagCount,
  }) async {
    // 检查是否已存在
    if (state.config.hasGroup(groupTitle)) {
      throw Exception('Tag Group 已添加');
    }

    // 如果没有传入预估数量，则请求 API 获取
    int tagCount = estimatedTagCount ?? 0;
    if (estimatedTagCount == null) {
      try {
        final group = await _tagGroupService.getTagGroup(
          groupTitle,
          fetchPostCounts: false,
        );
        if (group != null) {
          // 过滤掉子组引用，只计算实际标签数量
          tagCount = group.tags
              .where((t) => !t.name.startsWith('tag_group'))
              .length;
        }
      } catch (e) {
        AppLogger.d(
          'Failed to get tag count for $groupTitle: $e',
          'TagGroupMapping',
        );
      }
    }

    final mapping = TagGroupMapping(
      id: const Uuid().v4(),
      groupTitle: groupTitle,
      displayName: displayName,
      targetCategory: targetCategory,
      createdAt: DateTime.now(),
      includeChildren: includeChildren,
      customMinPostCount: customMinPostCount,
      // 使用获取到的预估数量
      danbooruOriginalTagCount: tagCount,
      lastSyncedTagCount: tagCount,
    );

    final newMappings = [...state.config.mappings, mapping];
    final newConfig = state.config.copyWith(mappings: newMappings);
    await _saveConfig(newConfig);

    AppLogger.d(
      'Added tag group mapping: $displayName -> ${targetCategory.name} ($tagCount tags)',
      'TagGroupMapping',
    );
  }

  /// 更新 Tag Group 映射
  Future<void> updateMapping(TagGroupMapping mapping) async {
    final index = state.config.mappings.indexWhere((m) => m.id == mapping.id);
    if (index == -1) return;

    final newMappings = List<TagGroupMapping>.from(state.config.mappings);
    newMappings[index] = mapping;
    final newConfig = state.config.copyWith(mappings: newMappings);
    await _saveConfig(newConfig);
  }

  /// 切换映射启用状态
  Future<void> toggleMappingEnabled(String mappingId) async {
    final mapping = state.config.findMappingById(mappingId);
    if (mapping == null) return;

    await updateMapping(mapping.copyWith(enabled: !mapping.enabled));
  }

  /// 删除 Tag Group 映射
  Future<void> removeMapping(String mappingId) async {
    final newMappings = state.config.mappings
        .where((m) => m.id != mappingId)
        .toList();
    final newConfig = state.config.copyWith(mappings: newMappings);
    await _saveConfig(newConfig);

    AppLogger.d('Removed tag group mapping: $mappingId', 'TagGroupMapping');
  }

  /// 恢复默认配置
  Future<void> resetToDefault() async {
    final defaultConfig = DefaultTagGroupMappings.getDefaultConfig();
    await _saveConfig(defaultConfig);
    AppLogger.i('Tag group mapping reset to default', 'TagGroupMapping');
  }

  /// 批量更新选中的组
  /// 根据传入的 groupTitle 集合更新所有映射的 enabled 状态
  Future<void> updateSelectedGroups(Set<String> selectedGroupTitles) async {
    final updatedMappings = state.config.mappings.map((m) {
      final shouldBeEnabled = selectedGroupTitles.contains(m.groupTitle);
      if (m.enabled != shouldBeEnabled) {
        return m.copyWith(enabled: shouldBeEnabled);
      }
      return m;
    }).toList();

    // 检查是否需要添加新的映射（选中但不存在的组）
    final existingGroupTitles = state.config.mappings.map((m) => m.groupTitle).toSet();
    final newGroupTitles = selectedGroupTitles.difference(existingGroupTitles);

    // 如果有新选中的组，需要添加映射
    // 注意：这里需要从预定义树中获取信息
    if (newGroupTitles.isNotEmpty) {
      AppLogger.d(
        'Adding new group mappings: ${newGroupTitles.join(", ")}',
        'TagGroupMapping',
      );
      // 新映射将在后续调用 addMapping 时添加
    }

    final newConfig = state.config.copyWith(mappings: updatedMappings);
    await _saveConfig(newConfig);

    AppLogger.d(
      'Updated selected groups: ${selectedGroupTitles.length} groups selected',
      'TagGroupMapping',
    );
  }

  /// 批量更新选中的组（完整版本，包含添加新映射）
  /// [estimatedTagCounts] 可选的预估标签数量映射，避免批量请求 API
  Future<void> updateSelectedGroupsWithTree(
    Set<String> selectedGroupTitles,
    Map<String, ({String displayName, TagSubCategory category, bool includeChildren})> groupInfoMap, {
    Map<String, int>? estimatedTagCounts,
  }) async {
    final existingGroupTitles = state.config.mappings.map((m) => m.groupTitle).toSet();

    // 更新现有映射的 enabled 状态
    final updatedMappings = state.config.mappings.map((m) {
      final shouldBeEnabled = selectedGroupTitles.contains(m.groupTitle);
      if (m.enabled != shouldBeEnabled) {
        return m.copyWith(enabled: shouldBeEnabled);
      }
      return m;
    }).toList();

    // 添加新的映射
    final newGroupTitles = selectedGroupTitles.difference(existingGroupTitles).toList();

    if (newGroupTitles.isNotEmpty) {
      // 并发获取所有新组的标签数量（限制并发数为 5）
      final tagCounts = <String, int>{};

      if (estimatedTagCounts != null) {
        // 使用传入的预估数量
        tagCounts.addAll(estimatedTagCounts);
      } else {
        // 并发请求，限制并发数
        const batchSize = 5;
        for (var i = 0; i < newGroupTitles.length; i += batchSize) {
          final batch = newGroupTitles.skip(i).take(batchSize).toList();
          final futures = batch.map((groupTitle) async {
            try {
              final group = await _tagGroupService.getTagGroup(
                groupTitle,
                fetchPostCounts: false,
              );
              if (group != null) {
                return MapEntry(
                  groupTitle,
                  group.tags.where((t) => !t.name.startsWith('tag_group')).length,
                );
              }
            } catch (e) {
              AppLogger.d('Failed to get tag count for $groupTitle: $e', 'TagGroupMapping');
            }
            return MapEntry(groupTitle, 0);
          });

          final results = await Future.wait(futures);
          for (final entry in results) {
            tagCounts[entry.key] = entry.value;
          }
        }
      }

      // 创建新映射
      for (final groupTitle in newGroupTitles) {
        final info = groupInfoMap[groupTitle];
        if (info != null) {
          final count = tagCounts[groupTitle] ?? 0;
          updatedMappings.add(TagGroupMapping(
            id: const Uuid().v4(),
            groupTitle: groupTitle,
            displayName: info.displayName,
            targetCategory: info.category,
            createdAt: DateTime.now(),
            includeChildren: info.includeChildren,
            enabled: true,
            danbooruOriginalTagCount: count,
            lastSyncedTagCount: count,
          ),);
        }
      }
    }

    final newConfig = state.config.copyWith(mappings: updatedMappings);
    await _saveConfig(newConfig);

    AppLogger.i(
      'Updated selected groups: ${selectedGroupTitles.length} selected, ${newGroupTitles.length} new',
      'TagGroupMapping',
    );
  }

  /// 搜索 Tag Groups
  Future<List<TagGroup>> searchTagGroups(String query) async {
    if (query.trim().isEmpty) {
      return _tagGroupService.getTopLevelTagGroups();
    }
    return _tagGroupService.searchTagGroups(query: query, limit: 50);
  }

  /// 获取指定 Tag Group 的详细信息
  Future<TagGroup?> getTagGroup(String groupTitle) async {
    // 先检查缓存
    if (state.cachedGroups.containsKey(groupTitle)) {
      return state.cachedGroups[groupTitle];
    }

    final group = await _tagGroupService.getTagGroup(
      groupTitle,
      fetchPostCounts: true,
    );

    if (group != null) {
      // 更新缓存
      final newCache = Map<String, TagGroup>.from(state.cachedGroups);
      newCache[groupTitle] = group;
      state = state.copyWith(cachedGroups: newCache);
    }

    return group;
  }

  /// 预览 Tag Group 标签（应用热度筛选）
  Future<TagGroup?> previewTagGroup(
    String groupTitle, {
    int? minPostCount,
  }) async {
    final effectiveMinPostCount = minPostCount ?? state.config.minPostCount;

    final group = await _tagGroupService.syncTagGroup(
      groupTitle: groupTitle,
      minPostCount: effectiveMinPostCount,
      maxTags: state.config.maxTagsPerGroup,
      includeChildren: true,
    );

    return group;
  }

  /// 同步 Tag Group 标签
  Future<bool> syncTagGroups() async {
    if (state.isSyncing) return false;

    final enabledMappings = state.config.enabledMappings;
    if (enabledMappings.isEmpty) {
      return true;
    }

    state = state.copyWith(isSyncing: true, error: null);

    try {
      // 获取 Tag Group 标签
      final syncResult = await _tagGroupService.syncTagGroupMappings(
        mappings: enabledMappings,
        minPostCount: state.config.minPostCount,
        maxTagsPerGroup: state.config.maxTagsPerGroup,
        onProgress: (progress) {
          state = state.copyWith(syncProgress: progress);
        },
      );

      if (!syncResult.success) {
        throw Exception(syncResult.error ?? '同步失败');
      }

      // 转换为 WeightedTag 并合并到词库
      final tagsByCategory = <TagSubCategory, List<WeightedTag>>{};
      for (final entry in syncResult.tagsByCategory.entries) {
        final category = TagSubCategory.values.firstWhere(
          (c) => c.name == entry.key,
          orElse: () => TagSubCategory.other,
        );
        tagsByCategory[category] = _libraryService.tagGroupEntriesToWeightedTags(
          entry.value,
        );
      }

      // 合并到词库
      final libraryNotifier = ref.read(tagLibraryNotifierProvider.notifier);
      await libraryNotifier.mergeTagGroupTags(tagsByCategory);

      // 更新映射的同步信息
      final now = DateTime.now();
      final updatedMappings = state.config.mappings.map((m) {
        if (!m.enabled) return m;
        final tagCount = syncResult.tagCountByGroup[m.groupTitle] ?? 0;
        final originalCount = syncResult.originalTagCountByGroup[m.groupTitle] ?? 0;
        return m.copyWith(
          lastSyncedAt: now,
          lastSyncedTagCount: tagCount,
          danbooruOriginalTagCount: originalCount,
        );
      }).toList();

      final newConfig = state.config.copyWith(
        mappings: updatedMappings,
        lastFullSyncTime: now,
      );
      await _saveConfig(newConfig);

      state = state.copyWith(isSyncing: false, syncProgress: null);
      AppLogger.i(
        'Tag group sync completed: ${syncResult.totalFilteredTags} tags',
        'TagGroupMapping',
      );
      return true;
    } catch (e, stack) {
      AppLogger.e('Tag group sync failed: $e', e, stack, 'TagGroupMapping');
      state = state.copyWith(
        isSyncing: false,
        syncProgress: null,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 保存配置
  Future<void> _saveConfig(TagGroupSyncConfig config) async {
    await _libraryService.saveTagGroupSyncConfig(config);
    state = state.copyWith(config: config);
  }

  /// 同步指定分类的 TagGroup 映射
  Future<bool> syncCategoryTagGroups(TagSubCategory category) async {
    if (state.isSyncing) return false;

    final categoryMappings = state.config.mappings
        .where((m) => m.enabled && m.targetCategory == category)
        .toList();

    if (categoryMappings.isEmpty) return true;

    state = state.copyWith(isSyncing: true, error: null);

    try {
      final syncResult = await _tagGroupService.syncTagGroupMappings(
        mappings: categoryMappings,
        minPostCount: state.config.minPostCount,
        maxTagsPerGroup: state.config.maxTagsPerGroup,
        onProgress: (progress) {
          state = state.copyWith(syncProgress: progress);
        },
      );

      if (!syncResult.success) {
        throw Exception(syncResult.error ?? '同步失败');
      }

      // 转换为 WeightedTag 并合并到词库
      final tagsByCategory = <TagSubCategory, List<WeightedTag>>{};
      for (final entry in syncResult.tagsByCategory.entries) {
        final cat = TagSubCategory.values.firstWhere(
          (c) => c.name == entry.key,
          orElse: () => TagSubCategory.other,
        );
        tagsByCategory[cat] = _libraryService.tagGroupEntriesToWeightedTags(
          entry.value,
        );
      }

      // 合并到词库
      final libraryNotifier = ref.read(tagLibraryNotifierProvider.notifier);
      await libraryNotifier.mergeTagGroupTags(tagsByCategory);

      // 更新映射的同步信息
      final now = DateTime.now();
      final updatedMappings = state.config.mappings.map((m) {
        if (!m.enabled || m.targetCategory != category) return m;
        final tagCount = syncResult.tagCountByGroup[m.groupTitle] ?? 0;
        final originalCount = syncResult.originalTagCountByGroup[m.groupTitle] ?? 0;
        return m.copyWith(
          lastSyncedAt: now,
          lastSyncedTagCount: tagCount,
          danbooruOriginalTagCount: originalCount,
        );
      }).toList();

      final newConfig = state.config.copyWith(mappings: updatedMappings);
      await _saveConfig(newConfig);

      state = state.copyWith(isSyncing: false, syncProgress: null);
      AppLogger.i(
        'Category sync completed: ${category.name}, ${syncResult.totalFilteredTags} tags',
        'TagGroupMapping',
      );
      return true;
    } catch (e, stack) {
      AppLogger.e('Category sync failed: $e', e, stack, 'TagGroupMapping');
      state = state.copyWith(
        isSyncing: false,
        syncProgress: null,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 清除缓存
  void clearCache() {
    _tagGroupService.clearCache();
    state = state.copyWith(cachedGroups: {});
  }
}
