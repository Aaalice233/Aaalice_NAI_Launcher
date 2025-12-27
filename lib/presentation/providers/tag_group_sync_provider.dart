import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/datasources/local/tag_group_cache_service.dart';
import '../../data/datasources/remote/danbooru_tag_group_service.dart';
import '../../data/models/prompt/tag_category.dart';
import '../../data/models/prompt/tag_group.dart';
import '../../data/models/prompt/tag_group_mapping.dart';
import '../../data/models/prompt/weighted_tag.dart';
import '../../data/services/tag_library_service.dart';
import 'random_preset_provider.dart';
import 'tag_library_provider.dart';

part 'tag_group_sync_provider.g.dart';

/// Tag Group 同步状态
class TagGroupSyncState {
  final bool isSyncing;
  final TagGroupSyncProgress? syncProgress;
  final String? error;

  /// 按当前热度阈值实时计算的过滤后标签数量
  final Map<String, int> filteredTagCounts;

  const TagGroupSyncState({
    this.isSyncing = false,
    this.syncProgress,
    this.error,
    this.filteredTagCounts = const {},
  });

  /// 总过滤后标签数
  int get totalFilteredTagCount =>
      filteredTagCounts.values.fold(0, (sum, c) => sum + c);

  TagGroupSyncState copyWith({
    bool? isSyncing,
    TagGroupSyncProgress? syncProgress,
    String? error,
    Map<String, int>? filteredTagCounts,
  }) {
    return TagGroupSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
      error: error,
      filteredTagCounts: filteredTagCounts ?? this.filteredTagCounts,
    );
  }
}

/// Tag Group 同步服务
///
/// 负责：
/// 1. 同步 Tag Group 数据到本地缓存
/// 2. 管理同步进度状态
/// 3. 计算热度过滤后的标签数量
@Riverpod(keepAlive: true)
class TagGroupSyncNotifier extends _$TagGroupSyncNotifier {
  TagLibraryService get _libraryService => ref.read(tagLibraryServiceProvider);
  DanbooruTagGroupService get _tagGroupService =>
      ref.read(danbooruTagGroupServiceProvider);
  TagGroupCacheService get _cacheService =>
      ref.read(tagGroupCacheServiceProvider);

  @override
  TagGroupSyncState build() {
    _init();
    return const TagGroupSyncState();
  }

  Future<void> _init() async {
    try {
      await _cacheService.init();

      // 初始化时计算过滤数量
      final presetState = ref.read(randomPresetNotifierProvider);
      final preset = presetState.selectedPreset;
      if (preset != null && preset.tagGroupMappings.isNotEmpty) {
        await _updateFilteredCounts(preset.tagGroupMappings);
      }
    } catch (e) {
      AppLogger.e('Failed to init tag group sync: $e', 'TagGroupSync');
    }
  }

  /// 从缓存计算过滤后的标签数量
  Future<void> _updateFilteredCounts(List<TagGroupMapping> mappings) async {
    final enabledMappings = mappings.where((m) => m.enabled).toList();
    if (enabledMappings.isEmpty) {
      state = state.copyWith(filteredTagCounts: {});
      return;
    }

    final groupTitles = enabledMappings.map((m) => m.groupTitle).toList();

    // 使用异步方法计算（包含子组），不再使用热度阈值过滤
    final counts = await _cacheService.getFilteredTagCountsAsync(
      groupTitles,
      0, // 不应用额外的热度过滤
      includeChildren: true,
    );

    state = state.copyWith(filteredTagCounts: counts);

    AppLogger.d(
      'Updated filtered counts: ${counts.length} groups, total=${counts.values.fold(0, (sum, c) => sum + c)}',
      'TagGroupSync',
    );
  }

  /// 刷新过滤数量（当预设切换或映射变更时调用）
  Future<void> refreshFilteredCounts() async {
    final presetState = ref.read(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    if (preset != null) {
      await _updateFilteredCounts(preset.tagGroupMappings);
    }
  }

  /// 同步 Tag Group 标签
  Future<bool> syncTagGroups() async {
    if (state.isSyncing) return false;

    final presetState = ref.read(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    if (preset == null) return false;

    final enabledMappings = preset.tagGroupMappings.where((m) => m.enabled).toList();
    if (enabledMappings.isEmpty) {
      return true;
    }

    state = state.copyWith(isSyncing: true, error: null);

    // 清除缓存，确保使用最新的 API 数据
    _tagGroupService.clearCache();

    try {
      // 获取 Tag Group 标签
      final syncResult = await _tagGroupService.syncTagGroupMappings(
        mappings: enabledMappings,
        minPostCount: 0, // 不应用全局热度过滤，由各 TagGroup 自己的设置控制
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
      final updatedMappings = preset.tagGroupMappings.map((m) {
        if (!m.enabled) return m;
        final tagCount = syncResult.tagCountByGroup[m.groupTitle] ?? 0;
        final originalCount = syncResult.originalTagCountByGroup[m.groupTitle] ?? 0;

        return m.copyWith(
          lastSyncedAt: now,
          lastSyncedTagCount: tagCount,
          danbooruOriginalTagCount: originalCount,
        );
      }).toList();

      // 更新预设
      await ref.read(randomPresetNotifierProvider.notifier)
          .updatePreset(preset.copyWith(tagGroupMappings: updatedMappings));

      // 同步完成后计算过滤数量
      await _updateFilteredCounts(updatedMappings);

      state = state.copyWith(isSyncing: false, syncProgress: null);
      AppLogger.i(
        'Tag group sync completed: ${syncResult.totalFilteredTags} tags',
        'TagGroupSync',
      );
      return true;
    } catch (e, stack) {
      AppLogger.e('Tag group sync failed: $e', e, stack, 'TagGroupSync');
      state = state.copyWith(
        isSyncing: false,
        syncProgress: null,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 同步指定分类的 TagGroup 映射
  Future<bool> syncCategoryTagGroups(TagSubCategory category) async {
    if (state.isSyncing) return false;

    final presetState = ref.read(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    if (preset == null) return false;

    final categoryMappings = preset.tagGroupMappings
        .where((m) => m.enabled && m.targetCategory == category)
        .toList();

    if (categoryMappings.isEmpty) return true;

    state = state.copyWith(isSyncing: true, error: null);

    try {
      final syncResult = await _tagGroupService.syncTagGroupMappings(
        mappings: categoryMappings,
        minPostCount: 0, // 不应用全局热度过滤
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
      final updatedMappings = preset.tagGroupMappings.map((m) {
        if (!m.enabled || m.targetCategory != category) return m;
        final tagCount = syncResult.tagCountByGroup[m.groupTitle] ?? 0;
        final originalCount = syncResult.originalTagCountByGroup[m.groupTitle] ?? 0;
        return m.copyWith(
          lastSyncedAt: now,
          lastSyncedTagCount: tagCount,
          danbooruOriginalTagCount: originalCount,
        );
      }).toList();

      // 更新预设
      await ref.read(randomPresetNotifierProvider.notifier)
          .updatePreset(preset.copyWith(tagGroupMappings: updatedMappings));

      // 同步完成后计算过滤数量
      await _updateFilteredCounts(updatedMappings);

      state = state.copyWith(isSyncing: false, syncProgress: null);
      AppLogger.i(
        'Category sync completed: ${category.name}, ${syncResult.totalFilteredTags} tags',
        'TagGroupSync',
      );
      return true;
    } catch (e, stack) {
      AppLogger.e('Category sync failed: $e', e, stack, 'TagGroupSync');
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
    state = state.copyWith(filteredTagCounts: {});
  }
}
