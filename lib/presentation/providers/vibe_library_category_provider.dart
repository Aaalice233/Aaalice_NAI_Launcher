import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/vibe/vibe_library_category.dart';
import '../../data/services/vibe_library_storage_service.dart';

part 'vibe_library_category_provider.freezed.dart';
part 'vibe_library_category_provider.g.dart';

/// Vibe 库分类状态
@freezed
class VibeLibraryCategoryState with _$VibeLibraryCategoryState {
  const factory VibeLibraryCategoryState({
    /// 所有分类
    @Default([]) List<VibeLibraryCategory> categories,

    /// 当前选中的分类ID（null表示全部）
    String? selectedCategoryId,

    /// 是否正在加载
    @Default(false) bool isLoading,

    /// 是否正在同步
    @Default(false) bool isSyncing,

    /// 错误信息
    String? error,
  }) = _VibeLibraryCategoryState;

  const VibeLibraryCategoryState._();

  /// 获取当前选中的分类
  VibeLibraryCategory? get selectedCategory {
    if (selectedCategoryId == null) {
      return null;
    }
    return categories
        .cast<VibeLibraryCategory?>()
        .firstWhere(
          (c) => c?.id == selectedCategoryId,
          orElse: () => null,
        );
  }

  /// 是否选中"全部"
  bool get isAllSelected => selectedCategoryId == null;

  /// 根级分类
  List<VibeLibraryCategory> get rootCategories => categories.rootCategories;

  /// 获取分类树
  Map<String?, List<VibeLibraryCategory>> get categoryTree =>
      categories.buildTree();
}

/// Vibe 库分类状态管理
@riverpod
class VibeLibraryCategoryNotifier extends _$VibeLibraryCategoryNotifier {
  VibeLibraryStorageService get _storageService =>
      ref.read(vibeLibraryStorageServiceProvider);

  @override
  VibeLibraryCategoryState build() {
    // 初始化时加载分类
    Future.microtask(() => _loadCategories());
    return const VibeLibraryCategoryState(isLoading: true);
  }

  /// 加载分类列表
  Future<void> _loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final categories = await _storageService.getAllCategories();

      // 按排序顺序排列
      final sortedCategories = categories.sortedByOrder();

      state = state.copyWith(
        categories: sortedCategories,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      AppLogger.e('加载Vibe库分类失败', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: '加载分类失败: $e',
      );
    }
  }

  /// 刷新分类列表
  Future<void> refresh() async {
    await _loadCategories();
  }

  /// 选择分类
  void selectCategory(String? categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  /// 创建新分类
  Future<VibeLibraryCategory?> createCategory(
    String name, {
    String? parentId,
  }) async {
    if (name.trim().isEmpty) {
      state = state.copyWith(error: '分类名称不能为空');
      return null;
    }

    try {
      // 检查父分类是否存在
      if (parentId != null) {
        final parentExists = await _storageService.categoryExists(parentId);
        if (!parentExists) {
          state = state.copyWith(error: '父分类不存在');
          return null;
        }
      }

      // 计算新分类的排序顺序
      final siblings = parentId == null
          ? state.categories.rootCategories
          : state.categories.getChildren(parentId);
      final sortOrder = siblings.length;

      // 创建新分类
      final category = VibeLibraryCategory.create(
        name: name,
        parentId: parentId,
        sortOrder: sortOrder,
      );

      await _storageService.saveCategory(category);

      final updatedCategories = [...state.categories, category];
      state = state.copyWith(categories: updatedCategories);

      AppLogger.d('Vibe库分类创建成功: ${category.name}');
      return category;
    } catch (e, stackTrace) {
      AppLogger.e('创建Vibe库分类失败', e, stackTrace);
      state = state.copyWith(error: '创建分类失败: $e');
      return null;
    }
  }

  /// 重命名分类
  Future<VibeLibraryCategory?> renameCategory(
    String categoryId,
    String newName,
  ) async {
    if (newName.trim().isEmpty) {
      state = state.copyWith(error: '分类名称不能为空');
      return null;
    }

    final category = state.categories.findById(categoryId);
    if (category == null) {
      state = state.copyWith(error: '分类不存在');
      return null;
    }

    try {
      final renamed = await _storageService.updateCategoryName(
        categoryId,
        newName.trim(),
      );

      if (renamed != null) {
        // 更新分类列表
        final updatedCategories = state.categories
            .map((c) => c.id == categoryId ? renamed : c)
            .toList();

        state = state.copyWith(categories: updatedCategories);
        AppLogger.d('Vibe库分类重命名成功: ${renamed.name}');
        return renamed;
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.e('重命名Vibe库分类失败', e, stackTrace);
      state = state.copyWith(error: '重命名分类失败: $e');
      return null;
    }
  }

  /// 移动分类到新父级
  Future<VibeLibraryCategory?> moveCategory(
    String categoryId,
    String? newParentId,
  ) async {
    final category = state.categories.findById(categoryId);
    if (category == null) {
      state = state.copyWith(error: '分类不存在');
      return null;
    }

    // 检查循环引用
    if (newParentId != null &&
        state.categories.wouldCreateCycle(categoryId, newParentId)) {
      state = state.copyWith(error: '不能将分类移动到其子分类下');
      return null;
    }

    try {
      final moved = await _storageService.moveCategory(
        categoryId,
        newParentId,
      );

      if (moved != null) {
        // 更新分类列表
        final updatedCategories = state.categories
            .map((c) => c.id == categoryId ? moved : c)
            .toList();

        state = state.copyWith(categories: updatedCategories);
        AppLogger.d('Vibe库分类移动成功: ${moved.name}');
        return moved;
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.e('移动Vibe库分类失败', e, stackTrace);
      state = state.copyWith(error: '移动分类失败: $e');
      return null;
    }
  }

  /// 删除分类
  Future<bool> deleteCategory(
    String categoryId, {
    bool moveEntriesToParent = true,
  }) async {
    final category = state.categories.findById(categoryId);
    if (category == null) {
      state = state.copyWith(error: '分类不存在');
      return false;
    }

    // 检查是否有子分类
    final children = state.categories.getChildren(categoryId);
    if (children.isNotEmpty) {
      state = state.copyWith(error: '请先删除该分类下的子分类');
      return false;
    }

    try {
      final success = await _storageService.deleteCategory(
        categoryId,
        moveEntriesToParent: moveEntriesToParent,
      );

      if (success) {
        // 从列表中移除
        final updatedCategories =
            state.categories.where((c) => c.id != categoryId).toList();

        // 如果删除的是当前选中的分类，切换到"全部"
        final newSelectedId = state.selectedCategoryId == categoryId
            ? null
            : state.selectedCategoryId;

        state = state.copyWith(
          categories: updatedCategories,
          selectedCategoryId: newSelectedId,
        );

        AppLogger.d('Vibe库分类删除成功: ${category.name}');
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      AppLogger.e('删除Vibe库分类失败', e, stackTrace);
      state = state.copyWith(error: '删除分类失败: $e');
      return false;
    }
  }

  /// 重新排序分类
  Future<void> reorderCategories(
    String? parentId,
    int oldIndex,
    int newIndex,
  ) async {
    try {
      // 获取同级分类
      final siblings = parentId == null
          ? state.categories.rootCategories.sortedByOrder()
          : state.categories.getChildren(parentId).sortedByOrder();

      if (oldIndex < 0 ||
          oldIndex >= siblings.length ||
          newIndex < 0 ||
          newIndex >= siblings.length) {
        return;
      }

      // 重新排序
      final reordered = [...siblings];
      final item = reordered.removeAt(oldIndex);
      reordered.insert(newIndex, item);

      // 更新排序顺序
      final updatedSiblings = reordered.asMap().entries.map((e) {
        return e.value.copyWith(
          sortOrder: e.key,
        );
      }).toList();

      // 保存到存储
      for (final category in updatedSiblings) {
        await _storageService.saveCategory(category);
      }

      // 更新完整分类列表
      final updatedCategories = state.categories.map((c) {
        final updated = updatedSiblings.where((s) => s.id == c.id).firstOrNull;
        return updated ?? c;
      }).toList();

      state = state.copyWith(categories: updatedCategories);
      AppLogger.d('Vibe库分类重新排序完成');
    } catch (e, stackTrace) {
      AppLogger.e('重新排序Vibe库分类失败', e, stackTrace);
      state = state.copyWith(error: '重新排序失败: $e');
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 获取分类的完整路径
  String getCategoryPath(String categoryId) {
    return state.categories.getPathString(categoryId);
  }

  /// 获取分类及其所有子分类的ID
  Set<String> getCategoryWithDescendants(String categoryId) {
    return {
      categoryId,
      ...state.categories.getDescendantIds(categoryId),
    };
  }

  /// 获取指定分类下的所有条目ID（包括子分类）
  Future<Set<String>> getEntryIdsInCategory(String categoryId) async {
    final categoryIds = getCategoryWithDescendants(categoryId);
    final entryIds = <String>{};

    for (final id in categoryIds) {
      final entries = await _storageService.getEntriesByCategory(id);
      entryIds.addAll(entries.map((e) => e.id));
    }

    return entryIds;
  }
}

/// 扩展方法：根据ID查找分类
extension on List<VibeLibraryCategory> {
  VibeLibraryCategory? findById(String id) {
    return cast<VibeLibraryCategory?>().firstWhere(
      (c) => c?.id == id,
      orElse: () => null,
    );
  }
}
