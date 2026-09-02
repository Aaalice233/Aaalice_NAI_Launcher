import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synchronized/synchronized.dart';

import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/gallery_category.dart';
import '../../data/models/gallery/gallery_tree_drop_slot.dart';
import '../../data/repositories/gallery_category_repository.dart';
import 'category_operation_error.dart';

part 'gallery_category_provider.freezed.dart';
part 'gallery_category_provider.g.dart';

/// 画廊分类状态
@freezed
class GalleryCategoryState with _$GalleryCategoryState {
  const factory GalleryCategoryState({
    /// 所有分类
    @Default([]) List<GalleryCategory> categories,

    /// 当前选中的分类ID（null表示全部，'favorites'表示收藏）
    String? selectedCategoryId,

    /// 是否正在加载
    @Default(false) bool isLoading,

    /// 是否正在同步
    @Default(false) bool isSyncing,

    /// 错误信息
    CategoryOperationError? error,
  }) = _GalleryCategoryState;

  const GalleryCategoryState._();

  /// 获取当前选中的分类
  GalleryCategory? get selectedCategory {
    if (selectedCategoryId == null || selectedCategoryId == 'favorites') {
      return null;
    }
    return categories.findById(selectedCategoryId!);
  }

  /// 是否选中"全部"
  bool get isAllSelected => selectedCategoryId == null;

  /// 是否选中"收藏"
  bool get isFavoritesSelected => selectedCategoryId == 'favorites';

  /// 根级分类
  List<GalleryCategory> get rootCategories => categories.rootCategories;

  /// 获取分类树
  Map<String?, List<GalleryCategory>> get categoryTree =>
      categories.buildTree();
}

/// 画廊分类状态管理
@riverpod
class GalleryCategoryNotifier extends _$GalleryCategoryNotifier {
  final _repository = GalleryCategoryRepository.instance;
  final _moveLock = Lock();
  late Future<void> _initialLoad;

  @override
  GalleryCategoryState build() {
    // 分类是画廊导航状态；离开页面后保留，避免每次重新读取和统计。
    ref.keepAlive();
    _initialLoad = Future<void>.microtask(_loadCategories);
    return const GalleryCategoryState(isLoading: true);
  }

  Future<void> whenLoaded() => _initialLoad;

  /// 加载分类列表
  Future<void> _loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final categories = await _repository.loadCategories();

      // 更新每个分类的图片数量
      final updatedCategories = <GalleryCategory>[];
      for (final category in categories) {
        final count = await _repository.countImagesInCategory(category);
        updatedCategories.add(category.updateImageCount(count));
      }

      state = state.copyWith(categories: updatedCategories, isLoading: false);
    } catch (e) {
      AppLogger.e('加载分类失败', e);
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

  /// 与文件系统同步
  Future<void> syncWithFileSystem() async {
    state = state.copyWith(isSyncing: true, error: null);

    try {
      final syncedCategories = await _repository.syncWithFileSystem(
        state.categories,
      );

      // 保存同步后的分类
      await _repository.saveCategories(syncedCategories);

      state = state.copyWith(categories: syncedCategories, isSyncing: false);
    } catch (e) {
      AppLogger.e('同步分类失败', e);
      state = state.copyWith(
        isSyncing: false,
        error: CategoryOperationError(
          CategoryOperationErrorCode.syncFailed,
          details: e.toString(),
        ),
      );
    }
  }

  /// 选择分类
  void selectCategory(String? categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  /// 创建新分类
  Future<GalleryCategory?> createCategory(
    String name, {
    String? parentId,
  }) async {
    try {
      final category = await _repository.createCategory(
        name: name,
        parentId: parentId,
        existingCategories: state.categories,
      );

      if (category != null) {
        final updatedCategories = [...state.categories, category];
        await _repository.saveCategories(updatedCategories);

        state = state.copyWith(categories: updatedCategories);
        return category;
      }

      return null;
    } catch (e) {
      AppLogger.e('创建分类失败', e);
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
  Future<GalleryCategory?> renameCategory(
    String categoryId,
    String newName,
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

    try {
      final renamed = await _repository.renameCategory(
        category,
        newName,
        state.categories,
      );

      if (renamed != null) {
        // 更新分类列表
        var updatedCategories = state.categories
            .map((c) => c.id == categoryId ? renamed : c)
            .toList();

        // 更新所有子分类的路径
        final oldPath = category.folderPath;
        final newPath = renamed.folderPath;
        updatedCategories = _repository.updateDescendantPaths(
          oldPath,
          newPath,
          updatedCategories,
        );

        await _repository.saveCategories(updatedCategories);

        state = state.copyWith(categories: updatedCategories);
        return renamed;
      }

      return null;
    } catch (e) {
      AppLogger.e('重命名分类失败', e);
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
  Future<GalleryCategory?> moveCategory(
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
      final moved = await _repository.moveCategory(
        category,
        newParentId,
        state.categories,
      );

      if (moved != null) {
        // 更新分类列表
        var updatedCategories = state.categories
            .map((c) => c.id == categoryId ? moved : c)
            .toList();

        // 更新所有子分类的路径
        final oldPath = category.folderPath;
        final newPath = moved.folderPath;
        updatedCategories = _repository.updateDescendantPaths(
          oldPath,
          newPath,
          updatedCategories,
        );

        await _repository.saveCategories(updatedCategories);

        state = state.copyWith(categories: updatedCategories);
        return moved;
      }

      return null;
    } catch (e) {
      AppLogger.e('移动分类失败', e);
      state = state.copyWith(
        error: CategoryOperationError(
          CategoryOperationErrorCode.moveFailed,
          details: e.toString(),
        ),
      );
      return null;
    }
  }

  /// 按拖放槽位移动分类：
  /// - child：成为 target 的子分类（追加到末尾，含物理目录移动）
  /// - before/after：插入到 target 在其父级中的前/后；跨父时同时物理
  ///   移动目录（即“上移一级/跨层”），同父时仅重排顺序
  Future<bool> moveCategoryToSlot(
    String categoryId,
    String targetId,
    GalleryTreeDropSlot slot,
  ) {
    return _moveLock.synchronized(
      () => _moveCategoryToSlot(categoryId, targetId, slot),
    );
  }

  Future<bool> _moveCategoryToSlot(
    String categoryId,
    String targetId,
    GalleryTreeDropSlot slot,
  ) async {
    final category = state.categories.findById(categoryId);
    final target = state.categories.findById(targetId);
    if (category == null || target == null || categoryId == targetId) {
      return false;
    }
    final newParentId = slot == GalleryTreeDropSlot.child
        ? targetId
        : target.parentId;
    if (state.categories.wouldCreateCycle(categoryId, newParentId)) {
      return false;
    }

    GalleryCategory? physicallyMoved;
    var working = [...state.categories];
    try {
      if (category.parentId != newParentId) {
        physicallyMoved = await _repository.moveCategory(
          category,
          newParentId,
          working,
        );
        if (physicallyMoved == null) return false;
        working = working
            .map((c) => c.id == categoryId ? physicallyMoved! : c)
            .toList();
        working = _repository.updateDescendantPaths(
          category.folderPath,
          physicallyMoved.folderPath,
          working,
        );
      }

      final siblings =
          working
              .where((c) => c.parentId == newParentId && c.id != categoryId)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final orderedIds = [for (final sibling in siblings) sibling.id];
      switch (slot) {
        case GalleryTreeDropSlot.child:
          orderedIds.add(categoryId);
        case GalleryTreeDropSlot.before:
        case GalleryTreeDropSlot.after:
          final targetIndex = orderedIds.indexOf(targetId);
          final insertIndex = targetIndex == -1
              ? orderedIds.length
              : targetIndex + (slot == GalleryTreeDropSlot.after ? 1 : 0);
          orderedIds.insert(
            insertIndex.clamp(0, orderedIds.length),
            categoryId,
          );
      }

      if (category.parentId == newParentId) {
        final currentIds =
            (state.categories.where((c) => c.parentId == newParentId).toList()
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
                .map((c) => c.id)
                .toList();
        if (_sameOrder(currentIds, orderedIds)) return false;
      }

      working = working.map((c) {
        if (c.parentId != newParentId) return c;
        final index = orderedIds.indexOf(c.id);
        if (index == -1) return c;
        return c.copyWith(sortOrder: index, updatedAt: DateTime.now());
      }).toList();

      if (!await _repository.saveCategories(working)) {
        final rolledBack = await _rollbackPhysicalMove(
          physicallyMoved,
          category,
          working,
        );
        if (!rolledBack && await _repository.saveCategories(working)) {
          AppLogger.w(
            '分类目录回滚失败，已按实际目录状态补写配置: ${category.name}',
            'GalleryCategory',
          );
          state = state.copyWith(categories: working, error: null);
          return true;
        }
        state = state.copyWith(
          categories: rolledBack ? state.categories : working,
          error: CategoryOperationError(
            CategoryOperationErrorCode.moveFailed,
            details: rolledBack
                ? 'Category metadata persistence failed'
                : 'Category metadata persistence and directory rollback failed',
          ),
        );
        return false;
      }
      state = state.copyWith(categories: working, error: null);
      return true;
    } catch (e) {
      final rolledBack = await _rollbackPhysicalMove(
        physicallyMoved,
        category,
        working,
      );
      AppLogger.e('槽位移动分类失败', e, null, 'GalleryCategory');
      state = state.copyWith(
        categories: rolledBack ? state.categories : working,
        error: CategoryOperationError(
          CategoryOperationErrorCode.moveFailed,
          details: rolledBack ? e.toString() : '$e; directory rollback failed',
        ),
      );
      return false;
    }
  }

  Future<bool> _rollbackPhysicalMove(
    GalleryCategory? moved,
    GalleryCategory original,
    List<GalleryCategory> working,
  ) async {
    if (moved == null) return true;
    final rolledBack = await _repository.moveCategory(
      moved,
      original.parentId,
      working,
    );
    if (rolledBack != null) return true;
    AppLogger.e(
      '分类配置保存失败且目录回滚失败: ${original.name}',
      null,
      null,
      'GalleryCategory',
    );
    return false;
  }

  bool _sameOrder(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  /// 删除分类
  Future<bool> deleteCategory(
    String categoryId, {
    bool deleteFolder = true,
    bool recursive = false,
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
    if (children.isNotEmpty && !recursive) {
      state = state.copyWith(
        error: const CategoryOperationError(
          CategoryOperationErrorCode.hasSubcategories,
        ),
      );
      return false;
    }

    try {
      final success = await _repository.deleteCategory(
        category,
        state.categories,
        deleteFolder: deleteFolder,
        recursive: recursive,
      );

      if (success) {
        // 获取要删除的所有分类ID（包括子分类）
        final categoryIds = {
          categoryId,
          if (recursive) ...state.categories.getDescendantIds(categoryId),
        };

        // 从列表中移除
        final updatedCategories = state.categories
            .where((c) => !categoryIds.contains(c.id))
            .toList();

        await _repository.saveCategories(updatedCategories);

        // 如果删除的是当前选中的分类，切换到"全部"
        final newSelectedId =
            state.selectedCategoryId == categoryId ||
                (state.selectedCategoryId != null &&
                    categoryIds.contains(state.selectedCategoryId))
            ? null
            : state.selectedCategoryId;

        state = state.copyWith(
          categories: updatedCategories,
          selectedCategoryId: newSelectedId,
        );

        return true;
      }

      return false;
    } catch (e) {
      AppLogger.e('删除分类失败', e);
      state = state.copyWith(
        error: CategoryOperationError(
          CategoryOperationErrorCode.deleteFailed,
          details: e.toString(),
        ),
      );
      return false;
    }
  }

  /// 移动图片到分类
  Future<String?> moveImageToCategory(
    String imagePath,
    String? categoryId,
  ) async {
    GalleryCategory? category;
    if (categoryId != null && categoryId != 'favorites') {
      category = state.categories.findById(categoryId);
    }

    try {
      final newPath = await _repository.moveImageToCategory(
        imagePath,
        category,
      );

      if (newPath != null) {
        // 刷新分类图片数量
        await _updateCategoryImageCounts();
      }

      return newPath;
    } catch (e) {
      AppLogger.e('移动图片失败', e);
      state = state.copyWith(
        error: CategoryOperationError(
          CategoryOperationErrorCode.moveImageFailed,
          details: e.toString(),
        ),
      );
      return null;
    }
  }

  /// 批量移动图片到分类
  Future<int> moveImagesToCategory(
    List<String> imagePaths,
    String? categoryId,
  ) async {
    GalleryCategory? category;
    if (categoryId != null && categoryId != 'favorites') {
      category = state.categories.findById(categoryId);
    }

    try {
      final count = await _repository.moveImagesToCategory(
        imagePaths,
        category,
      );

      if (count > 0) {
        // 刷新分类图片数量
        await _updateCategoryImageCounts();
      }

      return count;
    } catch (e) {
      AppLogger.e('批量移动图片失败', e);
      state = state.copyWith(
        error: CategoryOperationError(
          CategoryOperationErrorCode.moveImagesFailed,
          details: e.toString(),
        ),
      );
      return 0;
    }
  }

  /// 更新所有分类的图片数量
  Future<void> _updateCategoryImageCounts() async {
    final updatedCategories = <GalleryCategory>[];

    for (final category in state.categories) {
      final count = await _repository.countImagesInCategory(category);
      updatedCategories.add(category.updateImageCount(count));
    }

    await _repository.saveCategories(updatedCategories);

    state = state.copyWith(categories: updatedCategories);
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
        return e.value.copyWith(sortOrder: e.key, updatedAt: DateTime.now());
      }).toList();

      // 更新完整分类列表
      final updatedCategories = state.categories.map((c) {
        final updated = updatedSiblings.where((s) => s.id == c.id).firstOrNull;
        return updated ?? c;
      }).toList();

      await _repository.saveCategories(updatedCategories);

      state = state.copyWith(categories: updatedCategories);
    } catch (e) {
      AppLogger.e('重新排序失败', e);
      state = state.copyWith(
        error: CategoryOperationError(
          CategoryOperationErrorCode.reorderFailed,
          details: e.toString(),
        ),
      );
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
    return {categoryId, ...state.categories.getDescendantIds(categoryId)};
  }
}
