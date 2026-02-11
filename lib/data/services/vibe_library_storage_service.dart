import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/app_logger.dart';
import '../models/vibe/vibe_library_category.dart';
import '../models/vibe/vibe_library_entry.dart';

part 'vibe_library_storage_service.g.dart';

/// Vibe 库存储服务
///
/// 负责 Vibe 库条目和分类的 CRUD 操作
/// 使用 Hive 本地存储，支持搜索、筛选和使用统计
class VibeLibraryStorageService {
  static const String _entriesBoxName = 'vibe_library_entries';
  static const String _categoriesBoxName = 'vibe_library_categories';

  Box<VibeLibraryEntry>? _entriesBox;
  Box<VibeLibraryCategory>? _categoriesBox;
  Future<void>? _initFuture;

  /// 初始化并注册 Hive adapters
  Future<void> init() async {
    // 注册 Hive adapters
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(VibeLibraryEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(VibeLibraryCategoryAdapter());
    }

    _entriesBox = await Hive.openBox<VibeLibraryEntry>(_entriesBoxName);
    _categoriesBox =
        await Hive.openBox<VibeLibraryCategory>(_categoriesBoxName);
    AppLogger.d('VibeLibraryStorageService initialized', 'VibeLibrary');
  }

  /// 确保已初始化（线程安全）
  Future<void> _ensureInit() async {
    if (_entriesBox != null &&
        _entriesBox!.isOpen &&
        _categoriesBox != null &&
        _categoriesBox!.isOpen) {
      return;
    }

    // 使用 Future 锁避免并发初始化
    _initFuture ??= init();
    await _initFuture;
  }

  // ==================== Entry CRUD ====================

  /// 保存条目（新增或更新）
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) async {
    await _ensureInit();
    try {
      await _entriesBox!.put(entry.id, entry);
      AppLogger.d('Entry saved: ${entry.displayName}', 'VibeLibrary');
      return entry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save entry: $e', 'VibeLibrary', stackTrace);
      rethrow;
    }
  }

  /// 根据 ID 获取条目
  Future<VibeLibraryEntry?> getEntry(String id) async {
    await _ensureInit();
    try {
      return _entriesBox!.get(id);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get entry: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 获取所有条目
  Future<List<VibeLibraryEntry>> getAllEntries() async {
    await _ensureInit();
    try {
      return _entriesBox!.values.toList();
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get all entries: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  /// 根据分类 ID 获取条目
  Future<List<VibeLibraryEntry>> getEntriesByCategory(
      String? categoryId) async {
    await _ensureInit();
    try {
      return _entriesBox!.values
          .where((entry) => entry.categoryId == categoryId)
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to get entries by category: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  /// 删除条目
  Future<bool> deleteEntry(String id) async {
    await _ensureInit();
    try {
      await _entriesBox!.delete(id);
      AppLogger.d('Entry deleted: $id', 'VibeLibrary');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete entry: $e', 'VibeLibrary', stackTrace);
      return false;
    }
  }

  /// 批量删除条目
  Future<int> deleteEntries(List<String> ids) async {
    await _ensureInit();
    try {
      await _entriesBox!.deleteAll(ids);
      AppLogger.d('Entries deleted: ${ids.length}', 'VibeLibrary');
      return ids.length;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete entries: $e', 'VibeLibrary', stackTrace);
      return 0;
    }
  }

  /// 搜索条目
  Future<List<VibeLibraryEntry>> searchEntries(String query) async {
    await _ensureInit();
    try {
      final allEntries = _entriesBox!.values.toList();
      if (query.isEmpty) return allEntries;

      final lowerQuery = query.toLowerCase();
      return allEntries.where((entry) {
        return entry.name.toLowerCase().contains(lowerQuery) ||
            entry.vibeDisplayName.toLowerCase().contains(lowerQuery) ||
            entry.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.e('Failed to search entries: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  /// 获取收藏的条目
  Future<List<VibeLibraryEntry>> getFavoriteEntries() async {
    await _ensureInit();
    try {
      return _entriesBox!.values.where((entry) => entry.isFavorite).toList();
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to get favorite entries: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  /// 获取最近使用的条目（按最后使用时间排序）
  Future<List<VibeLibraryEntry>> getRecentEntries({int limit = 20}) async {
    await _ensureInit();
    try {
      final entries = _entriesBox!.values
          .where((entry) => entry.lastUsedAt != null)
          .toList();
      entries.sort((a, b) => b.lastUsedAt!.compareTo(a.lastUsedAt!));
      return entries.take(limit).toList();
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to get recent entries: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  /// 增加使用次数
  Future<VibeLibraryEntry?> incrementUsedCount(String id) async {
    await _ensureInit();
    try {
      final entry = _entriesBox!.get(id);
      if (entry == null) return null;

      final updatedEntry = entry.recordUsage();
      await _entriesBox!.put(id, updatedEntry);
      AppLogger.d(
          'Entry usage incremented: ${entry.displayName}', 'VibeLibrary');
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to increment used count: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 切换收藏状态
  Future<VibeLibraryEntry?> toggleFavorite(String id) async {
    await _ensureInit();
    try {
      final entry = _entriesBox!.get(id);
      if (entry == null) return null;

      final updatedEntry = entry.toggleFavorite();
      await _entriesBox!.put(id, updatedEntry);
      AppLogger.d(
          'Entry favorite toggled: ${entry.displayName}', 'VibeLibrary');
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to toggle favorite: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 更新条目分类
  Future<VibeLibraryEntry?> updateEntryCategory(
    String id,
    String? categoryId,
  ) async {
    await _ensureInit();
    try {
      final entry = _entriesBox!.get(id);
      if (entry == null) return null;

      final updatedEntry = entry.copyWith(categoryId: categoryId);
      await _entriesBox!.put(id, updatedEntry);
      AppLogger.d(
          'Entry category updated: ${entry.displayName}', 'VibeLibrary');
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to update entry category: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 更新条目标签
  Future<VibeLibraryEntry?> updateEntryTags(
    String id,
    List<String> tags,
  ) async {
    await _ensureInit();
    try {
      final entry = _entriesBox!.get(id);
      if (entry == null) return null;

      final updatedEntry = entry.copyWith(tags: tags);
      await _entriesBox!.put(id, updatedEntry);
      AppLogger.d('Entry tags updated: ${entry.displayName}', 'VibeLibrary');
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to update entry tags: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 更新条目缩略图
  Future<VibeLibraryEntry?> updateEntryThumbnail(
    String id,
    Uint8List? thumbnail,
  ) async {
    await _ensureInit();
    try {
      final entry = _entriesBox!.get(id);
      if (entry == null) return null;

      final updatedEntry = entry.copyWith(thumbnail: thumbnail);
      await _entriesBox!.put(id, updatedEntry);
      AppLogger.d(
          'Entry thumbnail updated: ${entry.displayName}', 'VibeLibrary');
      return updatedEntry;
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to update entry thumbnail: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 获取条目数量
  Future<int> getEntriesCount() async {
    await _ensureInit();
    try {
      return _entriesBox!.length;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get entries count: $e', 'VibeLibrary', stackTrace);
      return 0;
    }
  }

  /// 获取指定分类的条目数量
  Future<int> getEntriesCountByCategory(String? categoryId) async {
    await _ensureInit();
    try {
      return _entriesBox!.values
          .where((entry) => entry.categoryId == categoryId)
          .length;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get entries count by category: $e', 'VibeLibrary',
          stackTrace);
      return 0;
    }
  }

  /// 检查条目是否存在
  Future<bool> entryExists(String id) async {
    await _ensureInit();
    try {
      return _entriesBox!.containsKey(id);
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to check entry existence: $e', 'VibeLibrary', stackTrace);
      return false;
    }
  }

  /// 清除所有条目
  Future<void> clearAllEntries() async {
    await _ensureInit();
    try {
      await _entriesBox!.clear();
      AppLogger.i('All entries cleared', 'VibeLibrary');
    } catch (e, stackTrace) {
      AppLogger.e('Failed to clear all entries: $e', 'VibeLibrary', stackTrace);
      rethrow;
    }
  }

  // ==================== Category CRUD ====================

  /// 保存分类（新增或更新）
  Future<VibeLibraryCategory> saveCategory(VibeLibraryCategory category) async {
    await _ensureInit();
    try {
      await _categoriesBox!.put(category.id, category);
      AppLogger.d('Category saved: ${category.name}', 'VibeLibrary');
      return category;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to save category: $e', 'VibeLibrary', stackTrace);
      rethrow;
    }
  }

  /// 根据 ID 获取分类
  Future<VibeLibraryCategory?> getCategory(String id) async {
    await _ensureInit();
    try {
      return _categoriesBox!.get(id);
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get category: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 获取所有分类
  Future<List<VibeLibraryCategory>> getAllCategories() async {
    await _ensureInit();
    try {
      return _categoriesBox!.values.toList();
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to get all categories: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  /// 获取根级分类
  Future<List<VibeLibraryCategory>> getRootCategories() async {
    await _ensureInit();
    try {
      return _categoriesBox!.values
          .where((category) => category.parentId == null)
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to get root categories: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  /// 获取子分类
  Future<List<VibeLibraryCategory>> getChildCategories(String parentId) async {
    await _ensureInit();
    try {
      return _categoriesBox!.values
          .where((category) => category.parentId == parentId)
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to get child categories: $e', 'VibeLibrary', stackTrace);
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
    await _ensureInit();
    try {
      final category = _categoriesBox!.get(id);
      if (category == null) return false;

      // 更新该分类下的条目
      final entriesInCategory = await getEntriesByCategory(id);
      for (final entry in entriesInCategory) {
        if (moveEntriesToParent && category.parentId != null) {
          await updateEntryCategory(entry.id, category.parentId);
        } else {
          await updateEntryCategory(entry.id, null);
        }
      }

      // 更新子分类的 parentId
      final childCategories = await getChildCategories(id);
      for (final child in childCategories) {
        final updatedChild = child.moveTo(category.parentId);
        await saveCategory(updatedChild);
      }

      await _categoriesBox!.delete(id);
      AppLogger.d('Category deleted: ${category.name}', 'VibeLibrary');
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to delete category: $e', 'VibeLibrary', stackTrace);
      return false;
    }
  }

  /// 批量删除分类
  Future<int> deleteCategories(List<String> ids) async {
    await _ensureInit();
    var deletedCount = 0;
    try {
      for (final id in ids) {
        if (await deleteCategory(id)) {
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
    await _ensureInit();
    try {
      final category = _categoriesBox!.get(id);
      if (category == null) return null;

      final updatedCategory = category.updateName(newName);
      await _categoriesBox!.put(id, updatedCategory);
      AppLogger.d('Category name updated: $newName', 'VibeLibrary');
      return updatedCategory;
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to update category name: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 移动分类到新父分类
  Future<VibeLibraryCategory?> moveCategory(
    String id,
    String? newParentId,
  ) async {
    await _ensureInit();
    try {
      final category = _categoriesBox!.get(id);
      if (category == null) return null;

      // 检查循环引用
      if (newParentId != null) {
        final allCategories = await getAllCategories();
        if (allCategories.wouldCreateCycle(id, newParentId)) {
          throw ArgumentError('Cannot move category: would create cycle');
        }
      }

      final updatedCategory = category.moveTo(newParentId);
      await _categoriesBox!.put(id, updatedCategory);
      AppLogger.d('Category moved: ${category.name}', 'VibeLibrary');
      return updatedCategory;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to move category: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 获取分类数量
  Future<int> getCategoriesCount() async {
    await _ensureInit();
    try {
      return _categoriesBox!.length;
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to get categories count: $e', 'VibeLibrary', stackTrace);
      return 0;
    }
  }

  /// 检查分类是否存在
  Future<bool> categoryExists(String id) async {
    await _ensureInit();
    try {
      return _categoriesBox!.containsKey(id);
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to check category existence: $e', 'VibeLibrary', stackTrace);
      return false;
    }
  }

  /// 清除所有分类
  Future<void> clearAllCategories() async {
    await _ensureInit();
    try {
      await _categoriesBox!.clear();
      AppLogger.i('All categories cleared', 'VibeLibrary');
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to clear all categories: $e', 'VibeLibrary', stackTrace);
      rethrow;
    }
  }

  // ==================== Utility ====================

  /// 获取所有标签
  Future<Set<String>> getAllTags() async {
    await _ensureInit();
    try {
      final tags = <String>{};
      for (final entry in _entriesBox!.values) {
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
    await _ensureInit();
    try {
      return _entriesBox!.values
          .where((entry) => entry.tags.contains(tag))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to get entries by tag: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  /// 获取按使用次数排序的条目
  Future<List<VibeLibraryEntry>> getEntriesByUsage({int limit = 20}) async {
    await _ensureInit();
    try {
      final entries = _entriesBox!.values.toList();
      entries.sort((a, b) => b.usedCount.compareTo(a.usedCount));
      return entries.take(limit).toList();
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to get entries by usage: $e', 'VibeLibrary', stackTrace);
      return [];
    }
  }

  // ==================== Generation State Persistence ====================

  static const String _generationStateKey = 'generation_state';

  /// 保存生成参数中的 Vibe 和精准参考状态
  Future<void> saveGenerationState({
    required List<Map<String, dynamic>> vibeReferences,
    required List<Map<String, dynamic>> preciseReferences,
    required bool normalizeVibeStrength,
  }) async {
    await _ensureInit();
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateData = {
        'vibeReferences': vibeReferences,
        'preciseReferences': preciseReferences,
        'normalizeVibeStrength': normalizeVibeStrength,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_generationStateKey, jsonEncode(stateData));
      AppLogger.d(
        'Generation state saved: ${vibeReferences.length} vibes, ${preciseReferences.length} precise refs',
        'VibeLibrary',
      );
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to save generation state: $e', 'VibeLibrary', stackTrace);
    }
  }

  /// 加载生成参数状态
  Future<Map<String, dynamic>?> loadGenerationState() async {
    await _ensureInit();
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_generationStateKey);
      if (jsonString != null) {
        final stateData = jsonDecode(jsonString) as Map<String, dynamic>;
        AppLogger.d('Generation state loaded', 'VibeLibrary');
        return stateData;
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to load generation state: $e', 'VibeLibrary', stackTrace);
      return null;
    }
  }

  /// 清除保存的生成状态
  Future<void> clearGenerationState() async {
    await _ensureInit();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_generationStateKey);
      AppLogger.d('Generation state cleared', 'VibeLibrary');
    } catch (e, stackTrace) {
      AppLogger.e(
          'Failed to clear generation state: $e', 'VibeLibrary', stackTrace);
    }
  }

  /// 关闭存储（清理资源）
  Future<void> close() async {
    try {
      if (_entriesBox != null && _entriesBox!.isOpen) {
        await _entriesBox!.close();
      }
      if (_categoriesBox != null && _categoriesBox!.isOpen) {
        await _categoriesBox!.close();
      }
      AppLogger.d('VibeLibraryStorageService closed', 'VibeLibrary');
    } catch (e, stackTrace) {
      AppLogger.e('Failed to close storage: $e', 'VibeLibrary', stackTrace);
    }
  }
}

/// Provider
@Riverpod(keepAlive: true)
VibeLibraryStorageService vibeLibraryStorageService(Ref ref) {
  return VibeLibraryStorageService();
}
