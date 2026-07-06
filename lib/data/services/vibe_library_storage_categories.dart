part of 'vibe_library_storage_service.dart';

mixin VibeLibraryStorageCategories {
  VibeLibraryStorageService get _categoryService =>
      this as VibeLibraryStorageService;

  // ==================== Category CRUD ====================

  /// 保存分类（新增或更新）
  Future<VibeLibraryCategory> saveCategory(VibeLibraryCategory category) async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      await service._categoriesBox!.put(category.id, category);
      AppLogger.d('Category saved: ${category.name}', 'VibeLibrary');
      return category;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save category: $e', 'VibeLibrary', stackTrace);
      rethrow;
    }
  }

  /// 根据 ID 获取分类
  Future<VibeLibraryCategory?> getCategory(String id) async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      return service._categoriesBox!.get(id);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get category: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 获取所有分类
  Future<List<VibeLibraryCategory>> getAllCategories() async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      return service._categoriesBox!.values.toList();
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to get all categories: $e',
        'VibeLibrary',
        stackTrace,
      );
      return [];
    }
  }

  /// 获取根级分类
  Future<List<VibeLibraryCategory>> getRootCategories() async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      return service._categoriesBox!.values
          .where((category) => category.parentId == null)
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to get root categories: $e',
        'VibeLibrary',
        stackTrace,
      );
      return [];
    }
  }

  /// 获取子分类
  Future<List<VibeLibraryCategory>> getChildCategories(String parentId) async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      return service._categoriesBox!.values
          .where((category) => category.parentId == parentId)
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to get child categories: $e',
        'VibeLibrary',
        stackTrace,
      );
      return [];
    }
  }

  /// 删除分类
  ///
  /// [moveEntriesToParent] 如果为 true，将分类下的条目移动到父分类；
  /// 如果为 false，将条目设为无分类（categoryId = null）
  Future<bool> deleteCategory(
    String id, {
    bool moveEntriesToParent = true,
  }) async {
    final service = _categoryService;
    await Future.wait([
      service._ensureEntriesBox(),
      service._ensureCategoriesBox(),
    ]);
    try {
      final category = service._categoriesBox!.get(id);
      if (category == null) return false;

      // 更新该分类下的条目
      final entriesInCategory = await service.getEntriesByCategory(id);
      for (final entry in entriesInCategory) {
        if (moveEntriesToParent && category.parentId != null) {
          await service.updateEntryCategory(entry.id, category.parentId);
        } else {
          await service.updateEntryCategory(entry.id, null);
        }
      }

      // 更新子分类的 parentId
      final childCategories = await service.getChildCategories(id);
      for (final child in childCategories) {
        final updatedChild = child.moveTo(category.parentId);
        await service.saveCategory(updatedChild);
      }

      await service._categoriesBox!.delete(id);
      AppLogger.d('Category deleted: ${category.name}', 'VibeLibrary');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete category: $e', 'VibeLibrary', stackTrace);
      return false;
    }
  }

  /// 批量删除分类
  Future<int> deleteCategories(List<String> ids) async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    var deletedCount = 0;
    try {
      for (final id in ids) {
        if (await service.deleteCategory(id)) {
          deletedCount++;
        }
      }
      AppLogger.d('Categories deleted: $deletedCount', 'VibeLibrary');
      return deletedCount;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete categories: $e', 'VibeLibrary', stackTrace);
      return deletedCount;
    }
  }

  /// 更新分类名称
  Future<VibeLibraryCategory?> updateCategoryName(
    String id,
    String newName,
  ) async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      final category = service._categoriesBox!.get(id);
      if (category == null) return null;

      final updatedCategory = category.updateName(newName);
      await service._categoriesBox!.put(id, updatedCategory);
      AppLogger.d('Category name updated: $newName', 'VibeLibrary');
      return updatedCategory;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to update category name: $e',
        'VibeLibrary',
        stackTrace,
      );
      return null;
    }
  }

  /// 移动分类到新父分类
  Future<VibeLibraryCategory?> moveCategory(
    String id,
    String? newParentId,
  ) async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      final category = service._categoriesBox!.get(id);
      if (category == null) return null;

      // 检查循环引用
      if (newParentId != null) {
        final allCategories = await service.getAllCategories();
        if (allCategories.wouldCreateCycle(id, newParentId)) {
          throw ArgumentError('Cannot move category: would create cycle');
        }
      }

      final updatedCategory = category.moveTo(newParentId);
      await service._categoriesBox!.put(id, updatedCategory);
      AppLogger.d('Category moved: ${category.name}', 'VibeLibrary');
      return updatedCategory;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to move category: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 获取分类数量
  Future<int> getCategoriesCount() async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      return service._categoriesBox!.length;
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to get categories count: $e',
        'VibeLibrary',
        stackTrace,
      );
      return 0;
    }
  }

  /// 检查分类是否存在
  Future<bool> categoryExists(String id) async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      return service._categoriesBox!.containsKey(id);
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to check category existence: $e',
        'VibeLibrary',
        stackTrace,
      );
      return false;
    }
  }

  /// 清除所有分类
  Future<void> clearAllCategories() async {
    final service = _categoryService;
    await service._ensureCategoriesBox();
    try {
      await service._categoriesBox!.clear();
      AppLogger.i('All categories cleared', 'VibeLibrary');
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to clear all categories: $e',
        'VibeLibrary',
        stackTrace,
      );
      rethrow;
    }
  }

  // ==================== Utility ====================

  /// 获取所有标签
  Future<Set<String>> getAllTags() async {
    final service = _categoryService;
    await service._ensureInit();
    try {
      final tags = <String>{};
      for (final entry in service._entriesBox!.values) {
        tags.addAll(entry.tags);
      }
      return tags;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get all tags: $e', 'VibeLibrary', stackTrace);
      return {};
    }
  }

  /// 按标签筛选条目
  Future<List<VibeLibraryEntry>> getEntriesByTag(String tag) async {
    final service = _categoryService;
    await service._ensureInit();
    try {
      return service._entriesBox!.values
          .where((entry) => entry.tags.contains(tag))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to get entries by tag: $e',
        'VibeLibrary',
        stackTrace,
      );
      return [];
    }
  }

  /// 获取按使用次数排序的条目
  Future<List<VibeLibraryEntry>> getEntriesByUsage({int limit = 20}) async {
    final service = _categoryService;
    await service._ensureInit();
    try {
      final entries = service._entriesBox!.values.toList();
      entries.sort((a, b) => b.usedCount.compareTo(a.usedCount));
      return entries.take(limit).toList();
    } catch (e, stackTrace) {
      AppLogger.e(
        'Failed to get entries by usage: $e',
        'VibeLibrary',
        stackTrace,
      );
      return [];
    }
  }
}
