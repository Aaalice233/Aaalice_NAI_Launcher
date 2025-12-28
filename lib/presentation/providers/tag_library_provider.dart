import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/prompt/category_filter_config.dart';
import '../../data/models/prompt/sync_config.dart';
import '../../data/models/prompt/tag_category.dart';
import '../../data/models/prompt/tag_library.dart';
import '../../data/models/prompt/weighted_tag.dart';
import '../../data/services/tag_library_service.dart';

part 'tag_library_provider.g.dart';

/// 词库状态
class TagLibraryState {
  final TagLibrary? library;
  final TagLibrarySyncConfig syncConfig;
  final CategoryFilterConfig categoryFilterConfig;
  final bool isLoading;
  final bool isSyncing;
  final SyncProgress? syncProgress;
  final String? error;

  const TagLibraryState({
    this.library,
    this.syncConfig = const TagLibrarySyncConfig(),
    this.categoryFilterConfig = const CategoryFilterConfig(),
    this.isLoading = false,
    this.isSyncing = false,
    this.syncProgress,
    this.error,
  });

  TagLibraryState copyWith({
    TagLibrary? library,
    TagLibrarySyncConfig? syncConfig,
    CategoryFilterConfig? categoryFilterConfig,
    bool? isLoading,
    bool? isSyncing,
    SyncProgress? syncProgress,
    String? error,
    bool clearError = false,
  }) {
    return TagLibraryState(
      library: library ?? this.library,
      syncConfig: syncConfig ?? this.syncConfig,
      categoryFilterConfig: categoryFilterConfig ?? this.categoryFilterConfig,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      syncProgress: syncProgress ?? this.syncProgress,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// 是否有可用词库
  bool get hasLibrary => library != null && library!.isValid;

  /// 获取总标签数
  int get totalTagCount => library?.totalTagCount ?? 0;
}

/// 词库管理 Provider
@Riverpod(keepAlive: true)
class TagLibraryNotifier extends _$TagLibraryNotifier {
  TagLibraryService? _service;

  @override
  TagLibraryState build() {
    _loadInitial();
    return const TagLibraryState(isLoading: true);
  }

  /// 获取服务实例
  TagLibraryService get _libraryService {
    _service ??= ref.read(tagLibraryServiceProvider);
    return _service!;
  }

  /// 初始加载
  Future<void> _loadInitial() async {
    try {
      await _libraryService.init();

      // 从 JSON 加载内置词库（不使用缓存）
      final library = await _libraryService.getAvailableLibrary();
      final config = await _libraryService.loadSyncConfig();
      final filterConfig = await _libraryService.loadCategoryFilterConfig();

      state = state.copyWith(
        library: library,
        syncConfig: config,
        categoryFilterConfig: filterConfig,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        library: _libraryService.getBuiltinLibrary(),
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 加载词库
  Future<void> loadLibrary() async {
    state = state.copyWith(isLoading: true);

    try {
      final library = await _libraryService.getAvailableLibrary();
      state = state.copyWith(
        library: library,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 同步词库
  Future<bool> syncLibrary() async {
    if (state.isSyncing) return false;

    state = state.copyWith(
      isSyncing: true,
      syncProgress: SyncProgress.initial(),
      clearError: true,
    );

    try {
      final library = await _libraryService.syncLibrary(
        range: state.syncConfig.dataRange,
        onProgress: (progress) {
          state = state.copyWith(syncProgress: progress);
        },
      );

      final newConfig = state.syncConfig.copyWith(
        lastSyncTime: DateTime.now(),
        status: SyncStatus.success,
        lastSyncTagCount: library.totalTagCount,
        lastError: null,
      );
      await _libraryService.saveSyncConfig(newConfig);

      state = state.copyWith(
        library: library,
        syncConfig: newConfig,
        isSyncing: false,
        syncProgress: SyncProgress.completed(library.totalTagCount),
      );

      return true;
    } catch (e) {
      final newConfig = state.syncConfig.copyWith(
        status: SyncStatus.failed,
        lastError: e.toString(),
      );
      await _libraryService.saveSyncConfig(newConfig);

      state = state.copyWith(
        syncConfig: newConfig,
        isSyncing: false,
        syncProgress: SyncProgress.failed(e.toString()),
        error: e.toString(),
      );

      return false;
    }
  }

  /// 更新同步配置
  Future<void> updateSyncConfig(TagLibrarySyncConfig config) async {
    await _libraryService.saveSyncConfig(config);
    state = state.copyWith(syncConfig: config);
  }

  /// 设置自动同步开关
  Future<void> setAutoSyncEnabled(bool enabled) async {
    final newConfig = state.syncConfig.copyWith(autoSyncEnabled: enabled);
    await updateSyncConfig(newConfig);
  }

  /// 设置同步间隔
  Future<void> setSyncInterval(int days) async {
    final newConfig = state.syncConfig.copyWith(syncIntervalDays: days);
    await updateSyncConfig(newConfig);
  }

  /// 设置数据范围
  Future<void> setDataRange(DataRange range) async {
    final newConfig = state.syncConfig.copyWith(dataRange: range);
    await updateSyncConfig(newConfig);
  }

  /// 更新分类过滤配置
  Future<void> updateCategoryFilterConfig(CategoryFilterConfig config) async {
    await _libraryService.saveCategoryFilterConfig(config);
    state = state.copyWith(categoryFilterConfig: config);
  }

  /// 设置指定分类的 Danbooru 补充开关
  Future<void> setCategoryEnabled(TagSubCategory category, bool enabled) async {
    final newConfig = state.categoryFilterConfig.setEnabled(category, enabled);
    await updateCategoryFilterConfig(newConfig);
  }

  /// 设置所有分类的 Danbooru 补充开关
  Future<void> setAllCategoriesEnabled(bool enabled) async {
    final newConfig = state.categoryFilterConfig.setAllEnabled(enabled);
    await updateCategoryFilterConfig(newConfig);
  }

  /// 检查指定分类是否启用 Danbooru 补充
  bool isCategoryEnabled(TagSubCategory category) {
    return state.categoryFilterConfig.isEnabled(category);
  }

  /// 设置指定分类的内置词库开关
  Future<void> setBuiltinEnabled(TagSubCategory category, bool enabled) async {
    final newConfig = state.categoryFilterConfig.setBuiltinEnabled(category, enabled);
    await updateCategoryFilterConfig(newConfig);
  }

  /// 设置所有分类的内置词库开关（批量操作，只写一次磁盘）
  Future<void> setAllBuiltinEnabled(bool enabled) async {
    final newConfig = state.categoryFilterConfig.setAllBuiltinEnabled(enabled);
    await updateCategoryFilterConfig(newConfig);
  }

  /// 检查指定分类是否启用内置词库
  bool isBuiltinEnabled(TagSubCategory category) {
    return state.categoryFilterConfig.isBuiltinEnabled(category);
  }

  /// 检查并自动同步（启动时调用）
  Future<void> checkAndAutoSync() async {
    if (!state.syncConfig.autoSyncEnabled) return;
    if (!state.syncConfig.shouldSync()) return;

    // 延迟执行，避免影响启动速度
    await Future.delayed(const Duration(seconds: 5));

    // 静默同步，不显示 Toast（Provider 中无法访问 BuildContext）
    await syncLibrary();
  }

  /// 清除缓存并重新加载内置词库
  Future<void> resetToBuiltin() async {
    await _libraryService.clearCache();
    final library = await _libraryService.getAvailableLibrary();
    state = state.copyWith(
      library: library,
      clearError: true,
    );
  }

  /// 合并 Pool 标签到当前词库
  ///
  /// 由 PoolMappingProvider 调用
  Future<void> mergePoolTags(Map<TagSubCategory, List<WeightedTag>> poolTags) async {
    if (state.library == null || poolTags.isEmpty) return;

    final mergedLibrary = _libraryService.mergePoolTags(state.library!, poolTags);
    await _libraryService.saveLibrary(mergedLibrary);
    state = state.copyWith(library: mergedLibrary);
  }

  /// 合并 TagGroup 标签到当前词库
  ///
  /// 由 TagGroupMappingProvider 调用
  Future<void> mergeTagGroupTags(Map<TagSubCategory, List<WeightedTag>> tagGroupTags) async {
    if (state.library == null || tagGroupTags.isEmpty) return;

    final mergedLibrary = _libraryService.mergeTagGroupTags(state.library!, tagGroupTags);
    await _libraryService.saveLibrary(mergedLibrary);
    state = state.copyWith(library: mergedLibrary);
  }
}

/// 便捷 Provider：获取当前词库
@riverpod
TagLibrary? currentTagLibrary(Ref ref) {
  return ref.watch(tagLibraryNotifierProvider).library;
}

/// 便捷 Provider：是否正在同步
@riverpod
bool isTagLibrarySyncing(Ref ref) {
  return ref.watch(tagLibraryNotifierProvider).isSyncing;
}

/// 便捷 Provider：同步进度
@riverpod
SyncProgress? tagLibrarySyncProgress(Ref ref) {
  return ref.watch(tagLibraryNotifierProvider).syncProgress;
}
