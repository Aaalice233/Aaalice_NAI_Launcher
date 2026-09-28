import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synchronized/synchronized.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/vibe/vibe_library_category.dart';
import '../../data/services/vibe_library_storage_service.dart';
import 'category_operation_error.dart';
import '../../data/models/gallery/gallery_tree_drop_slot.dart';
import '../../data/models/gallery/library_tree_order.dart';

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
    CategoryOperationError? error,
  }) = _VibeLibraryCategoryState;

  const VibeLibraryCategoryState._();

  /// 获取当前选中的分类
  VibeLibraryCategory? get selectedCategory {
    if (selectedCategoryId == null) {
      return null;
    }
    return categories.cast<VibeLibraryCategory?>().firstWhere(
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
  final _categoryMoveLock = Lock();
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

      state = state.copyWith(categories: sortedCategories, isLoading: false);
    } catch (e, stackTrace) {
      AppLogger.e('加载Vibe库分类失败', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: CategoryOperationError(
          CategoryOperationErrorCode.loadFailed,
          details: e.toString(),
        ),
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
      state = state.copyWith(
        error: const CategoryOperationError(
          CategoryOperationErrorCode.nameEmpty,
        ),
      );
      return null;
    }

    try {
      // 检查父分类是否存在
      if (parentId != null) {
        final parentExists = await _storageService.categoryExists(parentId);
        if (!parentExists) {
          state = state.copyWith(
            error: const CategoryOperationError(
              CategoryOperationErrorCode.parentNotFound,
            ),
          );
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
      state = state.copyWith(
        error: CategoryOperationError(
          CategoryOperationErrorCode.createFailed,
          details: e.toString(),
        ),
      );
      return null;
    }
  }

  /// 重命名分类
  Future<VibeLibraryCategory?> renameCategory(
    String categoryId,
    String newName,
  ) async {
    if (newName.trim().isEmpty) {
      state = state.copyWith(
        error: const CategoryOperationError(
          CategoryOperationErrorCode.nameEmpty,
        ),
      );
      return null;
    }

    final category = state.categories.findById(categoryId);
    if (category == null) {
      state = state.copyWith(
        error: const CategoryOperationError(
          CategoryOperationErrorCode.categoryNotFound,
        ),
      );
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
      state = state.copyWith(
        error: CategoryOperationError(
          CategoryOperationErrorCode.renameFailed,
          details: e.toString(),
        ),
      );
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
      state = state.copyWith(
        error: const CategoryOperationError(
          CategoryOperationErrorCode.categoryNotFound,
        ),
      );
      return null;
    }

    // 检查循环引用
    if (newParentId != null &&
        state.categories.wouldCreateCycle(categoryId, newParentId)) {
      state = state.copyWith(
        error: const CategoryOperationError(
          CategoryOperationErrorCode.invalidMove,
        ),
      );
      return null;
    }

    try {
      final moved = await _storageService.moveCategory(categoryId, newParentId);

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
      state = state.copyWith(
        error: CategoryOperationError(
          CategoryOperationErrorCode.moveFailed,
          details: e.toString(),
        ),
      );
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
      state = state.copyWith(
        error: const CategoryOperationError(
          CategoryOperationErrorCode.categoryNotFound,
        ),
      );
      return false;
    }

    // 检查是否有子分类
    final children = state.categories.getChildren(categoryId);
    if (children.isNotEmpty) {
      state = state.copyWith(
        error: const CategoryOperationError(
          CategoryOperationErrorCode.hasSubcategories,
        ),
      );
      return false;
    }

    try {
      final success = await _storageService.deleteCategory(
        categoryId,
        moveEntriesToParent: moveEntriesToParent,
      );

      if (success) {
        // 从列表中移除
        final updatedCategories = state.categories
            .where((c) => c.id != categoryId)
            .toList();

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
      state = state.copyWith(
        error: CategoryOperationError(
          CategoryOperationErrorCode.deleteFailed,
          details: e.toString(),
        ),
      );
      return false;
    }
  }

  Future<bool> moveCategoryToSlot(
    String categoryId,
    String targetId,
    GalleryTreeDropSlot slot, {
    Map<String, int>? displayOrder,
  }) => _categoryMoveLock.synchronized(() async {
    final storage = _storageService;
    final working = applyLibraryDisplayOrder(
      state.categories,
      displayOrder,
      idOf: (c) => c.id,
      withOrder: (c, order) => c.copyWith(sortOrder: order),
    );
    final updated = moveLibraryTreeItem(
      working,
      sourceId: categoryId,
      targetId: targetId,
      slot: slot,
      flat: true,
      idOf: (c) => c.id,
      parentOf: (c) => c.parentId,
      orderOf: (c) => c.sortOrder,
      withPlacement: (c, parent, order) =>
          c.copyWith(parentId: parent, sortOrder: order),
    );
    if (updated == null) return false;
    await storage.saveCategories(updated);
    state = state.copyWith(categories: updated, error: null);
    return true;
  });

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
    return {categoryId, ...state.categories.getDescendantIds(categoryId)};
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
