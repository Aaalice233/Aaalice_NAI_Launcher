import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/app_logger.dart';
import '../../core/constants/storage_keys.dart';

part 'tags_storage_service.g.dart';

/// 标签存储服务
///
/// 负责图片标签的加载、保存、删除等操作
/// 使用 Hive 本地存储，支持标签状态的持久化
/// 存储格式: Map<String, List<String>> (imagePath -> tag names)
class TagsStorageService {
  static const String _tagsKey = 'tags';

  Box? _box;
  Future<void>? _initFuture;

  /// 初始化
  Future<void> init() async {
    _box = await Hive.openBox(StorageKeys.tagsBox);
  }

  /// 确保已初始化（线程安全）
  Future<void> _ensureInit() async {
    if (_box != null && _box!.isOpen) return;

    // 使用 Future 锁避免并发初始化
    _initFuture ??= init();
    await _initFuture;
  }

  /// 加载所有标签
  ///
  /// 返回 Map<String, List<String>> 格式的标签数据
  /// key: 图片路径, value: 标签列表
  Future<Map<String, List<String>>> loadAllTags() async {
    await _ensureInit();
    try {
      final data = _box?.get(_tagsKey);
      if (data != null) {
        if (data is String) {
          // JSON 格式: Map 字符串
          final Map<String, dynamic> json = jsonDecode(data);
          return json.map(
            (key, value) => MapEntry(
              key,
              (value as List<dynamic>).cast<String>(),
            ),
          );
        } else if (data is Map) {
          // 直接的 Map 格式
          return data.map(
            (key, value) => MapEntry(
              key as String,
              (value as List<dynamic>).cast<String>(),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.e('Failed to load tags: $e', 'Tags');
    }
    return <String, List<String>>{};
  }

  /// 保存所有标签
  Future<void> saveAllTags(Map<String, List<String>> tags) async {
    await _ensureInit();
    try {
      final json = jsonEncode(tags);
      await _box?.put(_tagsKey, json);
      AppLogger.d(
        'Saved tags for ${tags.length} images',
        'Tags',
      );
    } catch (e) {
      AppLogger.e('Failed to save tags: $e', 'Tags');
      rethrow;
    }
  }

  /// 获取图片的所有标签
  Future<List<String>> getTagsForImage(String imagePath) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      return allTags[imagePath] ?? [];
    } catch (e) {
      AppLogger.e('Failed to get tags for image: $e', 'Tags');
      return [];
    }
  }

  /// 为图片添加标签
  ///
  /// 返回 true 如果标签被添加，false 如果标签已存在
  Future<bool> addTag(String imagePath, String tagName) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      final tags = allTags[imagePath] ?? [];

      if (tags.contains(tagName)) {
        AppLogger.d(
          'Tag already exists on image: $tagName',
          'Tags',
        );
        return false;
      }

      tags.add(tagName);
      allTags[imagePath] = tags;
      await saveAllTags(allTags);

      AppLogger.i(
        'Added tag to image: $imagePath -> $tagName',
        'Tags',
      );
      return true;
    } catch (e) {
      AppLogger.e('Failed to add tag: $e', 'Tags');
      rethrow;
    }
  }

  /// 为图片添加多个标签
  Future<int> addTags(String imagePath, List<String> tagNames) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      final tags = allTags[imagePath] ?? [];
      var addedCount = 0;

      for (final tagName in tagNames) {
        if (!tags.contains(tagName)) {
          tags.add(tagName);
          addedCount++;
        }
      }

      if (addedCount > 0) {
        allTags[imagePath] = tags;
        await saveAllTags(allTags);
        AppLogger.i(
          'Added $addedCount tags to image: $imagePath',
          'Tags',
        );
      }

      return addedCount;
    } catch (e) {
      AppLogger.e('Failed to add tags: $e', 'Tags');
      rethrow;
    }
  }

  /// 从图片移除标签
  ///
  /// 返回 true 如果标签被移除，false 如果标签不存在
  Future<bool> removeTag(String imagePath, String tagName) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      final tags = allTags[imagePath];

      if (tags == null || !tags.contains(tagName)) {
        AppLogger.d(
          'Tag not found on image: $tagName',
          'Tags',
        );
        return false;
      }

      tags.remove(tagName);

      // 如果标签列表为空，删除该图片的键
      if (tags.isEmpty) {
        allTags.remove(imagePath);
      } else {
        allTags[imagePath] = tags;
      }

      await saveAllTags(allTags);

      AppLogger.i(
        'Removed tag from image: $imagePath -> $tagName',
        'Tags',
      );
      return true;
    } catch (e) {
      AppLogger.e('Failed to remove tag: $e', 'Tags');
      rethrow;
    }
  }

  /// 从图片移除多个标签
  Future<int> removeTags(String imagePath, List<String> tagNames) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      final tags = allTags[imagePath];

      if (tags == null) {
        return 0;
      }

      var removedCount = 0;
      for (final tagName in tagNames) {
        if (tags.remove(tagName)) {
          removedCount++;
        }
      }

      if (removedCount > 0) {
        // 如果标签列表为空，删除该图片的键
        if (tags.isEmpty) {
          allTags.remove(imagePath);
        } else {
          allTags[imagePath] = tags;
        }
        await saveAllTags(allTags);
        AppLogger.i(
          'Removed $removedCount tags from image: $imagePath',
          'Tags',
        );
      }

      return removedCount;
    } catch (e) {
      AppLogger.e('Failed to remove tags: $e', 'Tags');
      rethrow;
    }
  }

  /// 清除图片的所有标签
  Future<void> clearTagsForImage(String imagePath) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();

      if (!allTags.containsKey(imagePath)) {
        AppLogger.d(
          'No tags to clear for image: $imagePath',
          'Tags',
        );
        return;
      }

      allTags.remove(imagePath);
      await saveAllTags(allTags);

      AppLogger.i(
        'Cleared all tags for image: $imagePath',
        'Tags',
      );
    } catch (e) {
      AppLogger.e('Failed to clear tags: $e', 'Tags');
      rethrow;
    }
  }

  /// 检查图片是否有指定标签
  Future<bool> hasTag(String imagePath, String tagName) async {
    await _ensureInit();
    try {
      final tags = await getTagsForImage(imagePath);
      return tags.contains(tagName);
    } catch (e) {
      AppLogger.e('Failed to check tag: $e', 'Tags');
      return false;
    }
  }

  /// 获取所有使用过的唯一标签名称
  Future<Set<String>> getAllUniqueTagNames() async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      final uniqueTags = <String>{};

      for (final tags in allTags.values) {
        uniqueTags.addAll(tags);
      }

      return uniqueTags;
    } catch (e) {
      AppLogger.e('Failed to get unique tags: $e', 'Tags');
      return <String>{};
    }
  }

  /// 获取标签使用统计
  ///
  /// 返回 Map<String, int>，key 是标签名称，value 是使用次数
  Future<Map<String, int>> getTagUsageStats() async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      final stats = <String, int>{};

      for (final tags in allTags.values) {
        for (final tag in tags) {
          stats[tag] = (stats[tag] ?? 0) + 1;
        }
      }

      return stats;
    } catch (e) {
      AppLogger.e('Failed to get tag stats: $e', 'Tags');
      return <String, int>{};
    }
  }

  /// 获取有指定标签的所有图片路径
  Future<List<String>> getImagesWithTag(String tagName) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      final images = <String>[];

      for (final entry in allTags.entries) {
        if (entry.value.contains(tagName)) {
          images.add(entry.key);
        }
      }

      return images;
    } catch (e) {
      AppLogger.e('Failed to get images with tag: $e', 'Tags');
      return [];
    }
  }

  /// 获取有任意指定标签的所有图片路径
  Future<List<String>> getImagesWithAnyTag(List<String> tagNames) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      final images = <String>{};

      for (final entry in allTags.entries) {
        for (final tag in tagNames) {
          if (entry.value.contains(tag)) {
            images.add(entry.key);
            break;
          }
        }
      }

      return images.toList();
    } catch (e) {
      AppLogger.e('Failed to get images with tags: $e', 'Tags');
      return [];
    }
  }

  /// 获取有所有指定标签的所有图片路径
  Future<List<String>> getImagesWithAllTags(List<String> tagNames) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      final images = <String>[];

      for (final entry in allTags.entries) {
        final tags = entry.value;
        if (tagNames.every((tag) => tags.contains(tag))) {
          images.add(entry.key);
        }
      }

      return images;
    } catch (e) {
      AppLogger.e('Failed to get images with all tags: $e', 'Tags');
      return [];
    }
  }

  /// 重命名标签（批量更新所有使用该标签的图片）
  ///
  /// 返回更新了的图片数量
  Future<int> renameTag(String oldTagName, String newTagName) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      var updatedCount = 0;

      for (final entry in allTags.entries) {
        final tags = entry.value;
        if (tags.contains(oldTagName)) {
          tags.remove(oldTagName);
          if (!tags.contains(newTagName)) {
            tags.add(newTagName);
          }
          allTags[entry.key] = tags;
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await saveAllTags(allTags);
        AppLogger.i(
          'Renamed tag: $oldTagName -> $newTagName ($updatedCount images)',
          'Tags',
        );
      }

      return updatedCount;
    } catch (e) {
      AppLogger.e('Failed to rename tag: $e', 'Tags');
      rethrow;
    }
  }

  /// 删除标签（从所有图片中移除）
  ///
  /// 返回更新了的图片数量
  Future<int> deleteTag(String tagName) async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      var updatedCount = 0;

      final keysToUpdate = <String>[];
      for (final entry in allTags.entries) {
        if (entry.value.contains(tagName)) {
          keysToUpdate.add(entry.key);
        }
      }

      for (final key in keysToUpdate) {
        final tags = allTags[key]!;
        tags.remove(tagName);

        if (tags.isEmpty) {
          allTags.remove(key);
        } else {
          allTags[key] = tags;
        }
        updatedCount++;
      }

      if (updatedCount > 0) {
        await saveAllTags(allTags);
        AppLogger.i(
          'Deleted tag: $tagName ($updatedCount images)',
          'Tags',
        );
      }

      return updatedCount;
    } catch (e) {
      AppLogger.e('Failed to delete tag: $e', 'Tags');
      rethrow;
    }
  }

  /// 清除所有标签
  Future<void> clearAllTags() async {
    await _ensureInit();
    try {
      await _box?.delete(_tagsKey);
      AppLogger.i('Cleared all tags', 'Tags');
    } catch (e) {
      AppLogger.e('Failed to clear all tags: $e', 'Tags');
      rethrow;
    }
  }

  /// 获取有标签的图片总数
  Future<int> getTaggedImagesCount() async {
    await _ensureInit();
    try {
      final allTags = await loadAllTags();
      return allTags.length;
    } catch (e) {
      AppLogger.e('Failed to get tagged images count: $e', 'Tags');
      return 0;
    }
  }
}

/// Provider
@Riverpod(keepAlive: true)
TagsStorageService tagsStorageService(Ref ref) {
  return TagsStorageService();
}
