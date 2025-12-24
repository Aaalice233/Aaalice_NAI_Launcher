import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/local/tag_group_cache_service.dart';
import '../../data/datasources/remote/danbooru_tag_group_service.dart';
import '../../data/models/prompt/default_tag_group_mappings.dart';
import '../../data/models/prompt/tag_category.dart';
import '../../data/models/prompt/tag_group.dart';
import '../../data/models/prompt/tag_group_mapping.dart';
import '../../data/models/prompt/tag_group_preset_cache.dart';
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

  /// 按当前热度阈值实时计算的过滤后标签数量
  final Map<String, int> filteredTagCounts;

  const TagGroupMappingState({
    this.config = const TagGroupSyncConfig(),
    this.cachedGroups = const {},
    this.isLoading = false,
    this.isSyncing = false,
    this.syncProgress,
    this.error,
    this.filteredTagCounts = const {},
  });

  /// 总过滤后标签数
  int get totalFilteredTagCount =>
      filteredTagCounts.values.fold(0, (sum, c) => sum + c);

  TagGroupMappingState copyWith({
    TagGroupSyncConfig? config,
    Map<String, TagGroup>? cachedGroups,
    bool? isLoading,
    bool? isSyncing,
    TagGroupSyncProgress? syncProgress,
    String? error,
    Map<String, int>? filteredTagCounts,
  }) {
    return TagGroupMappingState(
      config: config ?? this.config,
      cachedGroups: cachedGroups ?? this.cachedGroups,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
      error: error,
      filteredTagCounts: filteredTagCounts ?? this.filteredTagCounts,
    );
  }
}

/// Tag Group 映射状态管理
@Riverpod(keepAlive: true)
class TagGroupMappingNotifier extends _$TagGroupMappingNotifier {
  TagLibraryService get _libraryService => ref.read(tagLibraryServiceProvider);
  DanbooruTagGroupService get _tagGroupService =>
      ref.read(danbooruTagGroupServiceProvider);
  TagGroupCacheService get _cacheService =>
      ref.read(tagGroupCacheServiceProvider);

  /// 防抖计时器，用于减少热度滑块调整时的计算频率
  Timer? _debounceTimer;

  /// 防抖延迟时间（毫秒）
  static const int _debounceDelayMs = 150;

  @override
  TagGroupMappingState build() {
    _loadConfig();
    return const TagGroupMappingState(isLoading: true);
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    try {
      final config = await _libraryService.loadTagGroupSyncConfig();

      // 初始化缓存服务
      await _cacheService.init();

      // 从持久化缓存加载数据到内存
      final enabledMappings = config.enabledMappings;
      if (enabledMappings.isNotEmpty) {
        final groupTitles = enabledMappings.map((m) => m.groupTitle).toList();
        await _cacheService.getTagGroups(groupTitles);
      }

      state = state.copyWith(
        config: config,
        isLoading: false,
      );

      // 计算初始过滤数量
      await _updateFilteredCounts(config.minPostCount);
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

  /// 设置最小热度阈值（触发实时过滤计算，带防抖）
  ///
  /// 配置会立即更新，但过滤计算会在 [_debounceDelayMs] 毫秒后执行，
  /// 避免滑块拖动时频繁计算影响性能。
  Future<void> setMinPostCount(int count) async {
    final newConfig = state.config.copyWith(minPostCount: count);

    // 立即更新配置（用户可立即看到滑块值变化）
    state = state.copyWith(config: newConfig);

    // 取消之前的防抖计时器
    _debounceTimer?.cancel();

    // 设置新的防抖计时器
    _debounceTimer = Timer(const Duration(milliseconds: _debounceDelayMs), () async {
      // 从缓存计算过滤后数量
      await _updateFilteredCounts(count);
      // 保存配置
      await _saveConfig(newConfig);
    });
  }

  /// 立即设置最小热度阈值（无防抖，用于非交互场景）
  Future<void> setMinPostCountImmediate(int count) async {
    _debounceTimer?.cancel();

    final newConfig = state.config.copyWith(minPostCount: count);
    state = state.copyWith(config: newConfig);

    await _updateFilteredCounts(count);
    await _saveConfig(newConfig);
  }

  /// 从缓存计算过滤后的标签数量
  Future<void> _updateFilteredCounts(int minPostCount) async {
    final enabledMappings = state.config.enabledMappings;
    if (enabledMappings.isEmpty) {
      state = state.copyWith(filteredTagCounts: {});
      return;
    }

    final groupTitles = enabledMappings.map((m) => m.groupTitle).toList();

    // 使用异步方法计算（包含子组）
    final counts = await _cacheService.getFilteredTagCountsAsync(
      groupTitles,
      minPostCount,
      includeChildren: true,
    );

    state = state.copyWith(filteredTagCounts: counts);

    AppLogger.d(
      'Updated filtered counts: ${counts.length} groups, total=${counts.values.fold(0, (sum, c) => sum + c)}',
      'TagGroupMapping',
    );
  }

  /// 设置每分组最大标签数
  Future<void> setMaxTagsPerGroup(int count) async {
    final newConfig = state.config.copyWith(maxTagsPerGroup: count);
    await _saveConfig(newConfig);
  }

  /// 添加 Tag Group 映射
  /// [estimatedTagCount] 可选的预估标签数量，如果传入则直接使用
  /// 不发起 API 请求，标签数量只在同步时更新
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

    // 只使用传入值，否则为 0（标签数量只在同步时更新）
    final tagCount = estimatedTagCount ?? 0;
    final originalCount = estimatedTagCount ?? 0;

    final mapping = TagGroupMapping(
      id: const Uuid().v4(),
      groupTitle: groupTitle,
      displayName: displayName,
      targetCategory: targetCategory,
      createdAt: DateTime.now(),
      includeChildren: includeChildren,
      customMinPostCount: customMinPostCount,
      // 使用获取到的预估数量
      danbooruOriginalTagCount: originalCount,
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
      // 使用预估数量（如果提供）> 预缓存值 > 0
      // 不发起 API 请求，标签数量只在同步时更新
      final tagCounts = estimatedTagCounts ?? <String, int>{};

      // 创建新映射
      for (final groupTitle in newGroupTitles) {
        final info = groupInfoMap[groupTitle];
        if (info != null) {
          // 优先使用传入的预估值，其次使用预缓存值，否则为 0
          final count = tagCounts[groupTitle]
              ?? TagGroupPresetCache.getCount(groupTitle)
              ?? 0;
          final originalCount = TagGroupPresetCache.getOriginalCount(groupTitle) ?? count;
          updatedMappings.add(TagGroupMapping(
            id: const Uuid().v4(),
            groupTitle: groupTitle,
            displayName: info.displayName,
            targetCategory: info.category,
            createdAt: DateTime.now(),
            includeChildren: info.includeChildren,
            enabled: true,
            danbooruOriginalTagCount: originalCount,
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

    // 清除缓存，确保使用最新的 API 数据
    _tagGroupService.clearCache();

    try {
      // 获取 Tag Group 标签（同步时不过滤，数据会保存到持久化缓存）
      final syncResult = await _tagGroupService.syncTagGroupMappings(
        mappings: enabledMappings,
        minPostCount: state.config.minPostCount,
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

      // 调试：打印同步结果
      AppLogger.d(
        'syncResult.tagCountByGroup keys: ${syncResult.tagCountByGroup.keys.toList()}',
        'TagGroupMapping',
      );
      AppLogger.d(
        'syncResult.tagCountByGroup: ${syncResult.tagCountByGroup}',
        'TagGroupMapping',
      );

      final updatedMappings = state.config.mappings.map((m) {
        if (!m.enabled) return m;
        final tagCount = syncResult.tagCountByGroup[m.groupTitle] ?? 0;
        final originalCount = syncResult.originalTagCountByGroup[m.groupTitle] ?? 0;

        // 调试：打印每个 mapping 的更新
        AppLogger.d(
          'Updating mapping: ${m.groupTitle} -> tagCount=$tagCount, originalCount=$originalCount',
          'TagGroupMapping',
        );

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

      // 同步完成后，根据当前阈值计算过滤数量
      await _updateFilteredCounts(state.config.minPostCount);

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

      // 同步完成后，根据当前阈值计算过滤数量
      await _updateFilteredCounts(state.config.minPostCount);

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
