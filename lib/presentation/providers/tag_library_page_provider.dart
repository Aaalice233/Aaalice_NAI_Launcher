import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/tag_library/tag_library_category.dart';
import '../../data/models/tag_library/tag_library_entry.dart';

part 'tag_library_page_provider.g.dart';

/// 词库视图模式
enum TagLibraryViewMode {
  /// 卡片视图
  card,

  /// 列表视图
  list,
}

/// 词库排序方式
enum TagLibrarySortBy {
  /// 按排序顺序
  order,

  /// 按名称
  name,

  /// 按使用次数
  useCount,

  /// 按更新时间
  updatedAt,
}

/// 词库页面状态
class TagLibraryPageState {
  final List<TagLibraryEntry> entries;
  final List<TagLibraryCategory> categories;
  final String? selectedCategoryId;
  final String searchQuery;
  final TagLibraryViewMode viewMode;
  final TagLibrarySortBy sortBy;
  final bool isLoading;
  final String? error;

  const TagLibraryPageState({
    this.entries = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
    this.viewMode = TagLibraryViewMode.card,
    this.sortBy = TagLibrarySortBy.order,
    this.isLoading = false,
    this.error,
  });

  TagLibraryPageState copyWith({
    List<TagLibraryEntry>? entries,
    List<TagLibraryCategory>? categories,
    String? selectedCategoryId,
    bool clearSelectedCategory = false,
    String? searchQuery,
    TagLibraryViewMode? viewMode,
    TagLibrarySortBy? sortBy,
    bool? isLoading,
    String? error,
  }) {
    return TagLibraryPageState(
      entries: entries ?? this.entries,
      categories: categories ?? this.categories,
      selectedCategoryId: clearSelectedCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      viewMode: viewMode ?? this.viewMode,
      sortBy: sortBy ?? this.sortBy,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 获取收藏条目数量
  int get favoritesCount => entries.where((e) => e.isFavorite).length;

  /// 获取所有条目数量
  int get totalCount => entries.length;

  /// 获取当前分类的条目
  List<TagLibraryEntry> get filteredEntries {
    var result = entries;

    // 按分类筛选
    if (selectedCategoryId != null) {
      if (selectedCategoryId == 'favorites') {
        result = result.where((e) => e.isFavorite).toList();
      } else {
        // 包括子分类的条目
        final categoryIds = {
          selectedCategoryId!,
          ...categories.getDescendantIds(selectedCategoryId!),
        };
        result =
            result.where((e) => categoryIds.contains(e.categoryId)).toList();
      }
    }

    // 搜索过滤
    if (searchQuery.isNotEmpty) {
      result = result.search(searchQuery);
    }

    // 排序
    List<TagLibraryEntry> sorted;
    switch (sortBy) {
      case TagLibrarySortBy.order:
        sorted = result.sortedByOrder();
      case TagLibrarySortBy.name:
        sorted = result.sortedByName();
      case TagLibrarySortBy.useCount:
        sorted = result.sortedByUseCount();
      case TagLibrarySortBy.updatedAt:
        sorted = result.sortedByUpdatedAt();
    }

    // 收藏条目始终排在前面（收藏夹视图除外，因为全部都是收藏）
    if (selectedCategoryId != 'favorites') {
      final favorites = sorted.where((e) => e.isFavorite).toList();
      final nonFavorites = sorted.where((e) => !e.isFavorite).toList();
      return [...favorites, ...nonFavorites];
    }

    return sorted;
  }

  /// 获取指定分类的条目数量
  int getCategoryEntryCount(String categoryId) {
    final categoryIds = {
      categoryId,
      ...categories.getDescendantIds(categoryId),
    };
    return entries.where((e) => categoryIds.contains(e.categoryId)).length;
  }
}

/// 词库页面 Provider
@Riverpod(keepAlive: true)
class TagLibraryPageNotifier extends _$TagLibraryPageNotifier {
  late LocalStorageService _storage;

  @override
  TagLibraryPageState build() {
    _storage = ref.watch(localStorageServiceProvider);
    // 直接返回加载的数据
    return _loadData();
  }

  /// 从存储加载数据
  TagLibraryPageState _loadData() {
    try {
      // 加载条目
      final entriesJson = _storage.getTagLibraryEntriesJson();
      List<TagLibraryEntry> entries = [];
      if (entriesJson != null && entriesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(entriesJson);
        entries = decoded
            .map((e) => TagLibraryEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
            .sortedByOrder();
      }

      // 加载分类
      final categoriesJson = _storage.getTagLibraryCategoriesJson();
      List<TagLibraryCategory> categories = [];
      if (categoriesJson != null && categoriesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(categoriesJson);
        categories = decoded
            .map(
              (e) => TagLibraryCategory.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
            .sortedByOrder();
      }

      AppLogger.d(
        'Loaded ${entries.length} entries, ${categories.length} categories',
        'TagLibraryPageProvider',
      );

      // 加载视图模式
      final viewModeIndex = _storage.getTagLibraryViewMode();
      final viewMode = viewModeIndex == 1
          ? TagLibraryViewMode.list
          : TagLibraryViewMode.card;

      return TagLibraryPageState(
        entries: entries,
        categories: categories,
        viewMode: viewMode,
      );
    } catch (e, stack) {
      AppLogger.e(
        'Failed to load tag library: $e',
        e,
        stack,
        'TagLibraryPageProvider',
      );
      return TagLibraryPageState(error: e.toString());
    }
  }

  /// 保存条目到存储
  Future<void> _saveEntries() async {
    try {
      final json = jsonEncode(state.entries.map((e) => e.toJson()).toList());
      await _storage.setTagLibraryEntriesJson(json);
    } catch (e, stack) {
      AppLogger.e(
        'Failed to save entries: $e',
        e,
        stack,
        'TagLibraryPageProvider',
      );
    }
  }

  /// 保存分类到存储
  Future<void> _saveCategories() async {
    try {
      final json = jsonEncode(state.categories.map((e) => e.toJson()).toList());
      await _storage.setTagLibraryCategoriesJson(json);
    } catch (e, stack) {
      AppLogger.e(
        'Failed to save categories: $e',
        e,
        stack,
        'TagLibraryPageProvider',
      );
    }
  }

  // ==================== 条目操作 ====================

  /// 添加条目
  Future<TagLibraryEntry> addEntry({
    required String name,
    required String content,
    String? thumbnail,
    List<String>? tags,
    String? categoryId,
    bool isFavorite = false,
  }) async {
    final entry = TagLibraryEntry.create(
      name: name,
      content: content,
      thumbnail: thumbnail,
      tags: tags,
      categoryId: categoryId,
      sortOrder: state.entries.length,
      isFavorite: isFavorite,
    );

    final newEntries = [...state.entries, entry];
    state = state.copyWith(entries: newEntries);
    await _saveEntries();

    AppLogger.d('Added entry: ${entry.displayName}', 'TagLibraryPageProvider');
    return entry;
  }

  /// 更新条目
  Future<void> updateEntry(TagLibraryEntry updatedEntry) async {
    final index = state.entries.indexWhere((e) => e.id == updatedEntry.id);
    if (index == -1) return;

    final newEntries = [...state.entries];
    newEntries[index] = updatedEntry;
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
  }

  /// 删除条目
  Future<void> deleteEntry(String entryId) async {
    final newEntries =
        state.entries.where((e) => e.id != entryId).toList().reindex();
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String entryId) async {
    final index = state.entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final newEntries = [...state.entries];
    newEntries[index] = newEntries[index].toggleFavorite();
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
  }

  /// 记录使用
  Future<void> recordUsage(String entryId) async {
    final index = state.entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final newEntries = [...state.entries];
    newEntries[index] = newEntries[index].recordUsage();
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
  }

  /// 移动条目到分类
  Future<void> moveEntryToCategory(String entryId, String? categoryId) async {
    final index = state.entries.indexWhere((e) => e.id == entryId);
    if (index == -1) return;

    final newEntries = [...state.entries];
    newEntries[index] = newEntries[index].copyWith(
      categoryId: categoryId,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
  }

  /// 批量删除条目
  Future<void> deleteEntries(List<String> entryIds) async {
    final newEntries =
        state.entries.where((e) => !entryIds.contains(e.id)).toList().reindex();
    state = state.copyWith(entries: newEntries);
    await _saveEntries();
  }

  /// 根据ID获取条目
  TagLibraryEntry? getEntry(String entryId) {
    return state.entries.cast<TagLibraryEntry?>().firstWhere(
          (e) => e?.id == entryId,
          orElse: () => null,
        );
  }

  // ==================== 分类操作 ====================

  /// 检查分类名称是否重复
  bool isCategoryNameDuplicate(String name, {String? excludeId}) {
    return state.categories.any(
      (c) =>
          c.name.toLowerCase() == name.toLowerCase() &&
          (excludeId == null || c.id != excludeId),
    );
  }

  /// 添加分类
  /// 返回新创建的分类，如果名称重复则返回 null
  Future<TagLibraryCategory?> addCategory({
    required String name,
    String? parentId,
  }) async {
    // 检查重名
    if (isCategoryNameDuplicate(name)) {
      AppLogger.w(
        'Category name "$name" already exists',
        'TagLibraryPageProvider',
      );
      return null;
    }

    final category = TagLibraryCategory.create(
      name: name,
      parentId: parentId,
      sortOrder: state.categories.where((c) => c.parentId == parentId).length,
    );

    final newCategories = [...state.categories, category];
    state = state.copyWith(categories: newCategories);
    await _saveCategories();

    AppLogger.d(
      'Added category: ${category.displayName}',
      'TagLibraryPageProvider',
    );
    return category;
  }

  /// 更新分类
  Future<void> updateCategory(TagLibraryCategory updatedCategory) async {
    final index =
        state.categories.indexWhere((c) => c.id == updatedCategory.id);
    if (index == -1) return;

    final newCategories = [...state.categories];
    newCategories[index] = updatedCategory;
    state = state.copyWith(categories: newCategories);
    await _saveCategories();
  }

  /// 删除分类
  Future<void> deleteCategory(String categoryId) async {
    // 获取所有要删除的分类ID（包括子分类）
    final categoryIds = {
      categoryId,
      ...state.categories.getDescendantIds(categoryId),
    };

    // 删除分类
    final newCategories = state.categories
        .where((c) => !categoryIds.contains(c.id))
        .toList()
        .reindex();

    // 将受影响的条目移到根级
    final newEntries = state.entries
        .map(
          (e) => categoryIds.contains(e.categoryId)
              ? e.copyWith(categoryId: null, updatedAt: DateTime.now())
              : e,
        )
        .toList();

    state = state.copyWith(
      categories: newCategories,
      entries: newEntries,
      clearSelectedCategory: state.selectedCategoryId != null &&
          categoryIds.contains(state.selectedCategoryId),
    );

    await _saveCategories();
    await _saveEntries();
  }

  /// 重命名分类
  /// 返回 true 表示成功，false 表示名称重复
  Future<bool> renameCategory(String categoryId, String newName) async {
    // 检查重名（排除自己）
    if (isCategoryNameDuplicate(newName, excludeId: categoryId)) {
      AppLogger.w(
        'Category name "$newName" already exists',
        'TagLibraryPageProvider',
      );
      return false;
    }

    final index = state.categories.indexWhere((c) => c.id == categoryId);
    if (index == -1) return false;

    final newCategories = [...state.categories];
    newCategories[index] = newCategories[index].updateName(newName);
    state = state.copyWith(categories: newCategories);
    await _saveCategories();
    return true;
  }

  /// 移动分类
  Future<void> moveCategory(String categoryId, String? newParentId) async {
    // 检查循环引用
    if (state.categories.wouldCreateCycle(categoryId, newParentId)) {
      AppLogger.w('Would create cycle, aborting', 'TagLibraryPageProvider');
      return;
    }

    final index = state.categories.indexWhere((c) => c.id == categoryId);
    if (index == -1) return;

    final newCategories = [...state.categories];
    newCategories[index] = newCategories[index].moveTo(newParentId);
    state = state.copyWith(categories: newCategories);
    await _saveCategories();
  }

  /// 分类同级重排序
  Future<void> reorderCategories(
    String? parentId,
    int oldIndex,
    int newIndex,
  ) async {
    // 获取同父级的分类
    final siblings = state.categories
        .where((c) => c.parentId == parentId)
        .toList()
        .sortedByOrder();

    if (oldIndex < 0 ||
        oldIndex >= siblings.length ||
        newIndex < 0 ||
        newIndex >= siblings.length) {
      return;
    }

    // 执行移动
    final movedCategory = siblings.removeAt(oldIndex);
    siblings.insert(newIndex, movedCategory);

    // 更新 sortOrder
    final updatedSiblings = siblings
        .asMap()
        .entries
        .map((e) => e.value.copyWith(sortOrder: e.key))
        .toList();

    // 合并到完整分类列表
    final otherCategories =
        state.categories.where((c) => c.parentId != parentId).toList();

    state =
        state.copyWith(categories: [...otherCategories, ...updatedSiblings]);
    await _saveCategories();

    AppLogger.d(
      'Reordered categories in parent $parentId: $oldIndex -> $newIndex',
      'TagLibraryPageProvider',
    );
  }

  /// 词条重排序（在当前筛选视图内）
  Future<void> reorderEntries(int oldIndex, int newIndex) async {
    final filteredEntries = state.filteredEntries;
    if (oldIndex < 0 ||
        oldIndex >= filteredEntries.length ||
        newIndex < 0 ||
        newIndex >= filteredEntries.length) {
      return;
    }

    // 获取要移动的词条
    final movedEntry = filteredEntries[oldIndex];
    final targetEntry = filteredEntries[newIndex];

    // 计算新的排序值
    final minSortOrder = movedEntry.sortOrder < targetEntry.sortOrder
        ? movedEntry.sortOrder
        : targetEntry.sortOrder;
    final maxSortOrder = movedEntry.sortOrder > targetEntry.sortOrder
        ? movedEntry.sortOrder
        : targetEntry.sortOrder;

    // 更新受影响的条目
    final newEntries = state.entries.map((entry) {
      if (entry.id == movedEntry.id) {
        return entry.copyWith(sortOrder: targetEntry.sortOrder);
      } else if (entry.sortOrder >= minSortOrder &&
          entry.sortOrder <= maxSortOrder) {
        // 调整中间条目的顺序
        if (movedEntry.sortOrder < targetEntry.sortOrder) {
          // 向后移动：中间的词条前移
          return entry.copyWith(sortOrder: entry.sortOrder - 1);
        } else {
          // 向前移动：中间的词条后移
          return entry.copyWith(sortOrder: entry.sortOrder + 1);
        }
      }
      return entry;
    }).toList();

    state = state.copyWith(entries: newEntries);
    await _saveEntries();

    AppLogger.d(
      'Reordered entries: $oldIndex -> $newIndex',
      'TagLibraryPageProvider',
    );
  }

  // ==================== 界面状态 ====================

  /// 选择分类
  void selectCategory(String? categoryId) {
    state = state.copyWith(
      selectedCategoryId: categoryId,
      clearSelectedCategory: categoryId == null,
    );
  }

  /// 设置搜索查询
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// 设置视图模式
  void setViewMode(TagLibraryViewMode mode) {
    state = state.copyWith(viewMode: mode);
    // 持久化视图模式
    _storage.setTagLibraryViewMode(
      mode == TagLibraryViewMode.list ? 1 : 0,
    );
  }

  /// 设置排序方式
  void setSortBy(TagLibrarySortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  /// 刷新数据
  void refresh() {
    state = _loadData();
  }

  /// 清除错误
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

  // ==================== 导入导出 ====================

  /// 批量导入条目
  ///
  /// [entries] 要导入的条目列表
  /// [categoryIdMapping] 分类ID映射（旧ID -> 新ID）
  /// [keepIds] 是否保留原始ID（用于替换场景）
  /// [nameSuffix] 名称后缀（用于重命名场景）
  Future<int> importEntries(
    List<TagLibraryEntry> entries, {
    Map<String, String>? categoryIdMapping,
    bool keepIds = false,
    String? nameSuffix,
  }) async {
    final newEntries = <TagLibraryEntry>[];
    var startSortOrder = state.entries.length;

    for (final entry in entries) {
      String? mappedCategoryId;
      if (entry.categoryId != null && categoryIdMapping != null) {
        mappedCategoryId = categoryIdMapping[entry.categoryId];
      }

      final newName = nameSuffix != null && nameSuffix.isNotEmpty
          ? '${entry.name}$nameSuffix'
          : entry.name;

      if (keepIds) {
        // 保留原始ID（替换场景）
        newEntries.add(
          entry.copyWith(
            name: newName,
            categoryId: mappedCategoryId ?? entry.categoryId,
            sortOrder: startSortOrder++,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        // 创建新ID（正常导入场景）
        newEntries.add(
          TagLibraryEntry.create(
            name: newName,
            content: entry.content,
            thumbnail: entry.thumbnail,
            tags: entry.tags,
            categoryId: mappedCategoryId ?? entry.categoryId,
            sortOrder: startSortOrder++,
            isFavorite: entry.isFavorite,
          ),
        );
      }
    }

    state = state.copyWith(entries: [...state.entries, ...newEntries]);
    await _saveEntries();

    return newEntries.length;
  }

  /// 批量导入分类
  ///
  /// [categories] 要导入的分类列表
  /// [keepIds] 是否保留原始ID（用于替换场景）
  /// [nameSuffix] 名称后缀（用于重命名场景）
  Future<Map<String, String>> importCategories(
    List<TagLibraryCategory> categories, {
    bool keepIds = false,
    String? nameSuffix,
  }) async {
    // 返回旧ID到新ID的映射
    final idMapping = <String, String>{};
    final newCategories = <TagLibraryCategory>[];
    var startSortOrder = state.categories.length;

    for (final category in categories) {
      final newName = nameSuffix != null && nameSuffix.isNotEmpty
          ? '${category.name}$nameSuffix'
          : category.name;

      if (keepIds) {
        // 保留原始ID（替换场景）
        final parentId = category.parentId != null
            ? idMapping[category.parentId]
            : null;
        newCategories.add(
          category.copyWith(
            name: newName,
            parentId: parentId,
            sortOrder: startSortOrder++,
          ),
        );
        idMapping[category.id] = category.id;
      } else {
        // 创建新ID（正常导入场景）
        final newCategory = TagLibraryCategory.create(
          name: newName,
          parentId:
              category.parentId != null ? idMapping[category.parentId] : null,
          sortOrder: startSortOrder++,
        );
        idMapping[category.id] = newCategory.id;
        newCategories.add(newCategory);
      }
    }

    state = state.copyWith(categories: [...state.categories, ...newCategories]);
    await _saveCategories();

    return idMapping;
  }
}

// ==================== 便捷 Providers ====================

/// 获取当前筛选后的条目
@riverpod
List<TagLibraryEntry> filteredTagLibraryPageEntries(Ref ref) {
  final state = ref.watch(tagLibraryPageNotifierProvider);
  return state.filteredEntries;
}

/// 获取词库条目总数
@riverpod
int tagLibraryPageEntryCount(Ref ref) {
  final state = ref.watch(tagLibraryPageNotifierProvider);
  return state.totalCount;
}

/// 获取收藏数量
@riverpod
int tagLibraryPageFavoritesCount(Ref ref) {
  final state = ref.watch(tagLibraryPageNotifierProvider);
  return state.favoritesCount;
}

/// 获取分类列表
@riverpod
List<TagLibraryCategory> tagLibraryPageCategories(Ref ref) {
  final state = ref.watch(tagLibraryPageNotifierProvider);
  return state.categories;
}

/// 获取根级分类
@riverpod
List<TagLibraryCategory> tagLibraryPageRootCategories(Ref ref) {
  final state = ref.watch(tagLibraryPageNotifierProvider);
  return state.categories.rootCategories.sortedByOrder();
}

/// 获取当前选中的分类ID
@riverpod
String? selectedTagLibraryPageCategoryId(Ref ref) {
  final state = ref.watch(tagLibraryPageNotifierProvider);
  return state.selectedCategoryId;
}

/// 获取当前视图模式
@riverpod
TagLibraryViewMode tagLibraryPageViewMode(Ref ref) {
  final state = ref.watch(tagLibraryPageNotifierProvider);
  return state.viewMode;
}
