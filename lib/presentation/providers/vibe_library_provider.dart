import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/vibe/vibe_library_category.dart';
import '../../data/models/vibe/vibe_library_entry.dart';
import '../../data/models/vibe/vibe_reference.dart';
import '../../data/services/vibe_file_storage_service.dart';
import '../../data/services/vibe_library_storage_service.dart';

part 'vibe_library_provider.freezed.dart';
part 'vibe_library_provider.g.dart';

/// Vibe 库状态
@freezed
class VibeLibraryState with _$VibeLibraryState {
  const factory VibeLibraryState({
    /// 所有条目
    @Default([]) List<VibeLibraryEntry> entries,

    /// 过滤后的条目
    @Default([]) List<VibeLibraryEntry> filteredEntries,

    /// 所有分类
    @Default([]) List<VibeLibraryCategory> categories,

    /// 当前页显示的条目
    @Default([]) List<VibeLibraryEntry> currentEntries,
    @Default(0) int currentPage,
    @Default(50) int pageSize,
    @Default(false) bool isLoading,
    @Default(false) bool isInitializing,

    /// 搜索关键词
    @Default('') String searchQuery,

    /// 选中的分类ID
    String? selectedCategoryId,

    /// 是否只显示收藏
    @Default(false) bool favoritesOnly,

    /// 排序方式
    @Default(VibeLibrarySortOrder.createdAt) VibeLibrarySortOrder sortOrder,

    /// 是否降序排列
    @Default(true) bool sortDescending,

    /// 错误信息
    String? error,
  }) = _VibeLibraryState;

  const VibeLibraryState._();

  int get totalPages =>
      filteredEntries.isEmpty ? 0 : (filteredEntries.length / pageSize).ceil();

  int get totalCount => entries.length;
  int get filteredCount => filteredEntries.length;

  /// 是否有活动过滤器
  bool get hasFilters =>
      searchQuery.isNotEmpty || selectedCategoryId != null || favoritesOnly;

  /// 获取当前选中的分类
  VibeLibraryCategory? get selectedCategory {
    if (selectedCategoryId == null) return null;
    return categories.cast<VibeLibraryCategory?>().firstWhere(
          (c) => c?.id == selectedCategoryId,
          orElse: () => null,
        );
  }

  /// 获取收藏的条目数量
  int get favoriteCount => entries.where((e) => e.isFavorite).length;

  /// 获取所有标签
  Set<String> get allTags {
    final tags = <String>{};
    for (final entry in entries) {
      tags.addAll(entry.tags);
    }
    return tags;
  }
}

/// Vibe 库排序方式
enum VibeLibrarySortOrder {
  createdAt,
  lastUsed,
  usedCount,
  name,
}

/// Vibe 库 Notifier
///
/// 管理 Vibe 库的状态和交互逻辑
@Riverpod(keepAlive: true)
class VibeLibraryNotifier extends _$VibeLibraryNotifier {
  late final VibeLibraryStorageService _storage;

  @override
  VibeLibraryState build() {
    _storage = ref.watch(vibeLibraryStorageServiceProvider);
    return const VibeLibraryState();
  }

  // ============================================================
  // 初始化与数据加载
  // ============================================================

  /// 初始化 Vibe 库
  Future<void> initialize() async {
    if (state.entries.isNotEmpty || state.isInitializing) return;
    await _loadData(isInitializing: true);
  }

  /// 重新加载数据
  Future<void> reload() async {
    // 先同步文件系统，确保文件增删反映在 Hive 中
    await syncWithFileSystem();
    await _loadData(isInitializing: false);
  }

  /// 仅从缓存加载数据（不扫描文件系统）- 用于快速显示
  Future<void> loadFromCache() async {
    await _loadData(isInitializing: false);
  }

  /// 与文件系统同步
  /// 扫描 vibes 文件夹，添加新文件到库，删除已不存在的文件条目
  /// 同步完成后自动刷新 UI
  Future<VibeFolderSyncResult> syncWithFileSystem() async {
    try {
      final result = await _storage.syncWithFileSystem(removeMissingEntries: true);
      AppLogger.i(
        'Vibe library synced: scanned=${result.scannedCount}, '
        'upserted=${result.upsertedCount}, deleted=${result.deletedCount}',
        'VibeLibrary',
      );
      
      // 同步完成后刷新数据
      if (result.upsertedCount > 0 || result.deletedCount > 0) {
        await _loadData(isInitializing: false);
      }
      
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to sync with file system', e, stackTrace, 'VibeLibrary');
      return VibeFolderSyncResult(
        scannedCount: 0,
        upsertedCount: 0,
        deletedCount: 0,
        failedCount: 1,
        errors: [e.toString()],
      );
    }
  }

  Future<void> _loadData({required bool isInitializing}) async {
    state = state.copyWith(isLoading: true, isInitializing: isInitializing);

    try {
      final entries = await _storage.getAllEntries();
      final categories = await _storage.getAllCategories();

      state = state.copyWith(
        entries: entries,
        categories: categories,
        isLoading: false,
        isInitializing: false,
      );
      await _applyFilters();
    } catch (e, stackTrace) {
      AppLogger.e('Failed to load vibe library', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
        isInitializing: false,
      );
    }
  }

  /// 加载指定页面
  Future<void> loadPage(int page) async {
    if (state.filteredEntries.isEmpty) {
      state = state.copyWith(currentEntries: [], currentPage: 0);
      return;
    }
    if (page < 0 || page >= state.totalPages) return;

    state = state.copyWith(currentPage: page);

    final start = page * state.pageSize;
    final end = min(start + state.pageSize, state.filteredEntries.length);
    final batch = state.filteredEntries.sublist(start, end);

    state = state.copyWith(currentEntries: batch);
  }

  /// 加载下一页
  Future<void> loadNextPage() => loadPage(state.currentPage + 1);

  /// 加载上一页
  Future<void> loadPreviousPage() => loadPage(state.currentPage - 1);

  // ============================================================
  // 搜索与过滤
  // ============================================================

  /// 设置搜索关键词
  Future<void> setSearchQuery(String query) =>
      _updateFilter(searchQuery: query.trim());

  /// 清除搜索
  Future<void> clearSearch() => _updateFilter(searchQuery: '');

  /// 设置分类过滤
  Future<void> setCategoryFilter(String? categoryId) =>
      _updateFilter(selectedCategoryId: categoryId);

  /// 清除分类过滤
  Future<void> clearCategoryFilter() => _updateFilter(selectedCategoryId: null);

  /// 设置只显示收藏
  Future<void> setFavoritesOnly(bool value) =>
      _updateFilter(favoritesOnly: value);

  /// 切换收藏过滤
  Future<void> toggleFavoritesOnly() =>
      _updateFilter(favoritesOnly: !state.favoritesOnly);

  Future<void> _updateFilter({
    String? searchQuery,
    String? selectedCategoryId,
    bool? favoritesOnly,
  }) async {
    final newSearchQuery = searchQuery ?? state.searchQuery;
    final newCategoryId = selectedCategoryId ?? state.selectedCategoryId;
    final newFavoritesOnly = favoritesOnly ?? state.favoritesOnly;

    if (state.searchQuery == newSearchQuery &&
        state.selectedCategoryId == newCategoryId &&
        state.favoritesOnly == newFavoritesOnly) {
      return;
    }

    state = state.copyWith(
      searchQuery: newSearchQuery,
      selectedCategoryId: selectedCategoryId != null || searchQuery == null
          ? newCategoryId
          : state.selectedCategoryId,
      favoritesOnly: newFavoritesOnly,
    );
    await _applyFilters();
  }

  /// 设置排序方式
  Future<void> setSortOrder(VibeLibrarySortOrder order) async {
    if (state.sortOrder == order) {
      // 如果相同，切换排序方向
      state = state.copyWith(sortDescending: !state.sortDescending);
    } else {
      state = state.copyWith(
        sortOrder: order,
        sortDescending: true,
      );
    }
    await _applyFilters();
  }

  /// 设置排序方向
  Future<void> setSortDescending(bool descending) async {
    if (state.sortDescending == descending) return;
    state = state.copyWith(sortDescending: descending);
    await _applyFilters();
  }

  /// 设置每页大小
  Future<void> setPageSize(int size) async {
    if (state.pageSize == size || size <= 0) return;
    state = state.copyWith(pageSize: size, currentPage: 0);
    await loadPage(0);
  }

  /// 清除所有过滤器
  Future<void> clearAllFilters() async {
    state = state.copyWith(
      searchQuery: '',
      selectedCategoryId: null,
      favoritesOnly: false,
    );
    await _applyFilters();
  }

  /// 应用过滤和排序
  Future<void> _applyFilters() async {
    var result = List<VibeLibraryEntry>.from(state.entries);

    if (state.searchQuery.isNotEmpty) {
      result = result.search(state.searchQuery);
    }
    if (state.selectedCategoryId != null) {
      result = result.getByCategory(state.selectedCategoryId);
    }
    if (state.favoritesOnly) {
      result = result.favorites;
    }

    result = _sortEntries(result);

    state = state.copyWith(filteredEntries: result, currentPage: 0);
    await loadPage(0);
  }

  List<VibeLibraryEntry> _sortEntries(List<VibeLibraryEntry> entries) {
    final sorted = switch (state.sortOrder) {
      VibeLibrarySortOrder.createdAt => entries.sortedByCreatedAt(),
      VibeLibrarySortOrder.lastUsed => entries.sortedByLastUsed(),
      VibeLibrarySortOrder.usedCount => entries.sortedByUsedCount(),
      VibeLibrarySortOrder.name => entries.sortedByName(),
    };
    return state.sortDescending ? sorted : sorted.reversed.toList();
  }

  // ============================================================
  // 条目操作
  // ============================================================

  /// 保存条目（新增或更新）
  Future<VibeLibraryEntry?> saveEntry(VibeLibraryEntry entry) async {
    try {
      final saved = await _storage.saveEntry(entry);
      final entries = [...state.entries];
      final index = entries.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        entries[index] = saved;
      } else {
        entries.add(saved);
      }
      state = state.copyWith(entries: entries);
      await _applyFilters();
      AppLogger.d('Entry saved: ${saved.displayName}', 'VibeLibrary');
      return saved;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save entry', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 保存 Bundle 条目
  Future<VibeLibraryEntry?> saveBundleEntry(
    List<VibeReference> vibes, {
    required String name,
    String? categoryId,
    List<String>? tags,
  }) async {
    try {
      final saved = await _storage.saveBundleEntry(
        vibes,
        name: name,
        categoryId: categoryId,
        tags: tags,
      );
      final entries = [...state.entries, saved];
      state = state.copyWith(entries: entries);
      await _applyFilters();
      AppLogger.d('Bundle entry saved: ${saved.displayName}', 'VibeLibrary');
      return saved;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save bundle entry', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 删除条目
  Future<bool> deleteEntry(String id) async {
    try {
      final success = await _storage.deleteEntry(id);
      if (!success) return false;

      // 更新本地状态
      final updatedEntries = state.entries.where((e) => e.id != id).toList();
      state = state.copyWith(entries: updatedEntries);
      await _applyFilters();

      AppLogger.d('Entry deleted: $id', 'VibeLibrary');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete entry', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 批量删除条目
  Future<int> deleteEntries(List<String> ids) async {
    try {
      final count = await _storage.deleteEntries(ids);

      // 更新本地状态
      final updatedEntries =
          state.entries.where((e) => !ids.contains(e.id)).toList();
      state = state.copyWith(entries: updatedEntries);
      await _applyFilters();

      AppLogger.d('Entries deleted: $count', 'VibeLibrary');
      return count;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete entries', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return 0;
    }
  }

  /// 切换收藏状态
  Future<VibeLibraryEntry?> toggleFavorite(String id) async {
    try {
      final updated = await _storage.toggleFavorite(id);
      if (updated == null) return null;

      // 更新本地状态
      final updatedEntries = state.entries.map((e) {
        return e.id == id ? updated : e;
      }).toList();

      state = state.copyWith(entries: updatedEntries);
      await _applyFilters();

      AppLogger.d(
        'Entry favorite toggled: ${updated.displayName}',
        'VibeLibrary',
      );
      return updated;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to toggle favorite', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 更新条目分类
  Future<VibeLibraryEntry?> updateEntryCategory(
    String id,
    String? categoryId,
  ) async {
    try {
      final updated = await _storage.updateEntryCategory(id, categoryId);
      if (updated == null) return null;

      // 更新本地状态
      final updatedEntries = state.entries.map((e) {
        return e.id == id ? updated : e;
      }).toList();

      state = state.copyWith(entries: updatedEntries);
      await _applyFilters();

      AppLogger.d(
        'Entry category updated: ${updated.displayName}',
        'VibeLibrary',
      );
      return updated;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to update entry category',
        e,
        stackTrace,
        'VibeLibrary',
      );
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 更新条目标签
  Future<VibeLibraryEntry?> updateEntryTags(
    String id,
    List<String> tags,
  ) async {
    try {
      final updated = await _storage.updateEntryTags(id, tags);
      if (updated == null) return null;

      // 更新本地状态
      final updatedEntries = state.entries.map((e) {
        return e.id == id ? updated : e;
      }).toList();

      state = state.copyWith(entries: updatedEntries);

      AppLogger.d('Entry tags updated: ${updated.displayName}', 'VibeLibrary');
      return updated;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to update entry tags', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 更新条目缩略图
  Future<VibeLibraryEntry?> updateEntryThumbnail(
    String id,
    Uint8List? thumbnail,
  ) async {
    try {
      final updated = await _storage.updateEntryThumbnail(id, thumbnail);
      if (updated == null) return null;

      // 更新本地状态
      final updatedEntries = state.entries.map((e) {
        return e.id == id ? updated : e;
      }).toList();

      state = state.copyWith(entries: updatedEntries);
      await _applyFilters();

      AppLogger.d(
        'Entry thumbnail updated: ${updated.displayName}',
        'VibeLibrary',
      );
      return updated;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to update entry thumbnail',
        e,
        stackTrace,
        'VibeLibrary',
      );
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 重命名条目（同步重命名文件）
  Future<VibeEntryRenameResult> renameEntry(String id, String newName) async {
    try {
      final result = await _storage.renameEntry(id, newName);
      if (!result.isSuccess) {
        return result;
      }

      final updated = result.entry!;
      final updatedEntries = state.entries.map((e) {
        return e.id == id ? updated : e;
      }).toList();

      state = state.copyWith(entries: updatedEntries);
      await _applyFilters();

      AppLogger.d('Entry renamed: ${updated.displayName}', 'VibeLibrary');
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to rename entry', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return const VibeEntryRenameResult.failure(
        VibeEntryRenameError.fileRenameFailed,
      );
    }
  }

  /// 记录条目使用
  Future<VibeLibraryEntry?> recordUsage(String id) async {
    try {
      final updated = await _storage.incrementUsedCount(id);
      if (updated == null) return null;

      // 更新本地状态
      final updatedEntries = state.entries.map((e) {
        return e.id == id ? updated : e;
      }).toList();

      state = state.copyWith(entries: updatedEntries);

      return updated;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to record usage', e, stackTrace, 'VibeLibrary');
      return null;
    }
  }

  // ============================================================
  // 分类操作
  // ============================================================

  /// 保存分类（新增或更新）
  Future<VibeLibraryCategory?> saveCategory(
    VibeLibraryCategory category,
  ) async {
    try {
      final saved = await _storage.saveCategory(category);

      // 更新本地状态
      final updatedCategories = [...state.categories];
      final index = updatedCategories.indexWhere((c) => c.id == category.id);
      if (index >= 0) {
        updatedCategories[index] = saved;
      } else {
        updatedCategories.add(saved);
      }

      state = state.copyWith(categories: updatedCategories);

      AppLogger.d('Category saved: ${saved.name}', 'VibeLibrary');
      return saved;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save category', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 删除分类
  Future<bool> deleteCategory(
    String id, {
    bool moveEntriesToParent = true,
  }) async {
    try {
      final success = await _storage.deleteCategory(
        id,
        moveEntriesToParent: moveEntriesToParent,
      );
      if (!success) return false;

      // 更新本地状态
      final updatedCategories =
          state.categories.where((c) => c.id != id).toList();
      state = state.copyWith(categories: updatedCategories);

      // 如果当前选中的是被删除的分类，清除选择
      if (state.selectedCategoryId == id) {
        await clearCategoryFilter();
      }

      // 重新加载条目（因为条目分类可能已更改）
      await reload();

      AppLogger.d('Category deleted: $id', 'VibeLibrary');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete category', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 更新分类名称
  Future<VibeLibraryCategory?> updateCategoryName(
    String id,
    String newName,
  ) async {
    try {
      final updated = await _storage.updateCategoryName(id, newName);
      if (updated == null) return null;

      // 更新本地状态
      final updatedCategories = state.categories.map((c) {
        return c.id == id ? updated : c;
      }).toList();

      state = state.copyWith(categories: updatedCategories);

      AppLogger.d('Category name updated: $newName', 'VibeLibrary');
      return updated;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to update category name',
        e,
        stackTrace,
        'VibeLibrary',
      );
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// 移动分类
  Future<VibeLibraryCategory?> moveCategory(
    String id,
    String? newParentId,
  ) async {
    try {
      final updated = await _storage.moveCategory(id, newParentId);
      if (updated == null) return null;

      // 更新本地状态
      final updatedCategories = state.categories.map((c) {
        return c.id == id ? updated : c;
      }).toList();

      state = state.copyWith(categories: updatedCategories);

      AppLogger.d('Category moved: ${updated.name}', 'VibeLibrary');
      return updated;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to move category', e, stackTrace, 'VibeLibrary');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  // ============================================================
  // 查询方法
  // ============================================================

  /// 根据 ID 获取条目
  VibeLibraryEntry? getEntryById(String id) {
    return state.entries.cast<VibeLibraryEntry?>().firstWhere(
          (e) => e?.id == id,
          orElse: () => null,
        );
  }

  /// 根据 ID 获取分类
  VibeLibraryCategory? getCategoryById(String id) {
    return state.categories.cast<VibeLibraryCategory?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
  }

  /// 获取指定分类下的条目数量
  int getEntryCountByCategory(String? categoryId) {
    return state.entries.where((e) => e.categoryId == categoryId).length;
  }

  /// 获取最近使用的条目
  List<VibeLibraryEntry> getRecentEntries({int limit = 10}) {
    return state.entries.sortedByLastUsed().take(limit).toList();
  }

  /// 获取最常使用的条目
  List<VibeLibraryEntry> getMostUsedEntries({int limit = 10}) {
    return state.entries.sortedByUsedCount().take(limit).toList();
  }

  /// 获取分类树结构
  Map<String?, List<VibeLibraryCategory>> get categoryTree {
    return state.categories.buildTree();
  }
}
